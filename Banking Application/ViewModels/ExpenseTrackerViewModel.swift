import Foundation
import Combine
import SwiftData
import SwiftUI

/// Owns Track-tab expense entries, categories, and budgets. Entries are
/// real `Transaction`s (not a parallel store), so they debit/credit the
/// chosen account the same way a payment would.
@MainActor
final class ExpenseTrackerViewModel: ObservableObject {

    @Published private(set) var expenseEntries: [Transaction] = []
    @Published private(set) var categories: [ExpenseCategory] = []
    @Published private(set) var budgets: [Budget] = []
    @Published var error: AppError?
    /// True once the deferred initial `reload()` (see `init`) has run at
    /// least once. Lets `TrackView` avoid flashing its "no expenses yet"
    /// empty state for the one frame before that first load completes.
    @Published private(set) var hasLoadedOnce = false

    private let modelContext: ModelContext
    private let accountViewModel: AccountViewModel
    private let transactionViewModel: TransactionViewModel

    init(
        modelContext: ModelContext,
        accountViewModel: AccountViewModel,
        transactionViewModel: TransactionViewModel
    ) {
        self.modelContext = modelContext
        self.accountViewModel = accountViewModel
        self.transactionViewModel = transactionViewModel
        // Deferred for the same reason as TransactionViewModel.init — see
        // that file's comment. This type is constructed live inside
        // TrackView.init, which runs during a view body evaluation, so the
        // synchronous-publish-during-init issue is not just theoretical here.
        Task { @MainActor [weak self] in
            self?.reload()
        }
    }

    var visibleCategories: [ExpenseCategory] {
        categories
            .filter { !$0.isHidden }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var amountSpentThisMonth: Decimal {
        let start = Self.startOfMonth(Date())
        return expenseEntries
            .filter { $0.isDebit && $0.transactionDate >= start }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    func filteredEntries(searchText: String, categoryId: String? = nil) -> [Transaction] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return expenseEntries.filter { entry in
            if let categoryId, entry.categoryRef?.id != categoryId {
                return false
            }
            guard !query.isEmpty else { return true }
            let haystack = [
                entry.merchant,
                entry.transactionDescription,
                entry.notes,
                entry.categoryRef?.name,
                entry.category
            ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
            return haystack.contains(query)
        }
    }

    func addExpense(
        account: Account,
        amount: Decimal,
        merchant: String?,
        description: String,
        categoryName: String,
        date: Date,
        source: TransactionEntrySource,
        isIncome: Bool,
        receiptImageData: Data? = nil,
        confidence: Double? = nil,
        notes: String? = nil
    ) {
        error = nil
        guard amount > 0 else {
            error = .invalidAmount
            return
        }

        if !isIncome, amount > account.availableBalance {
            error = .insufficientFunds
            return
        }

        let category = category(named: categoryName)
        applyBalanceChange(to: account, amount: amount, isIncome: isIncome)

        let txn = Transaction(
            accountId: account.id,
            type: isIncome ? .deposit : .payment,
            amount: amount,
            description: description,
            counterparty: merchant,
            transactionDate: date,
            category: category?.name ?? categoryName,
            merchant: merchant,
            entrySource: source,
            receiptImageData: receiptImageData,
            extractionConfidence: confidence,
            notes: notes,
            categoryRef: category
        )
        txn.account = account
        modelContext.insert(txn)

        persistAndReload()
        if error == nil {
            NotificationService.shared.notifyTransaction(
                amount: amount,
                title: isIncome ? "Income logged" : "Expense logged",
                body: "\(CurrencyFormatter.shared.string(from: amount)) · \(description)",
                remainingBalance: account.availableBalance
            )
        }
    }

    func updateExpense(
        _ transaction: Transaction,
        account: Account,
        amount: Decimal,
        merchant: String?,
        description: String,
        categoryName: String,
        date: Date,
        isIncome: Bool
    ) {
        error = nil
        guard amount > 0 else {
            error = .invalidAmount
            return
        }

        reverseBalanceChange(
            for: transaction,
            on: originalAccount(for: transaction)
        )

        if !isIncome, amount > account.availableBalance {
            applyBalanceChange(
                to: originalAccount(for: transaction) ?? account,
                amount: transaction.amount,
                isIncome: transaction.isCredit
            )
            error = .insufficientFunds
            persistAndReload()
            return
        }

        applyBalanceChange(to: account, amount: amount, isIncome: isIncome)

        let category = category(named: categoryName)
        transaction.accountId = account.id
        transaction.account = account
        transaction.type = isIncome ? .deposit : .payment
        transaction.amount = amount
        transaction.merchant = merchant
        transaction.counterparty = merchant
        transaction.transactionDescription = description
        transaction.category = category?.name ?? categoryName
        transaction.categoryRef = category
        transaction.transactionDate = date

        persistAndReload()
    }

    func deleteExpense(_ transaction: Transaction) {
        error = nil
        reverseBalanceChange(for: transaction, on: originalAccount(for: transaction))
        modelContext.delete(transaction)
        persistAndReload()
    }

    func wipeAllTrackerData() {
        error = nil
        for entry in expenseEntries {
            reverseBalanceChange(for: entry, on: originalAccount(for: entry))
            modelContext.delete(entry)
        }
        for budget in budgets {
            modelContext.delete(budget)
        }
        for category in categories where !category.isBuiltIn {
            modelContext.delete(category)
        }
        persistAndReload()
    }

    func exportCSV() -> String {
        ExpenseDataExporter.csv(for: expenseEntries)
    }

    func addCategory(name: String, systemImage: String, colorHex: String) {
        error = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = .invalidInput
            return
        }
        if categories.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame && !$0.isHidden }) {
            error = .unknownError("A category with that name already exists.")
            return
        }
        let nextOrder = (categories.map(\.sortOrder).max() ?? 0) + 1
        let category = ExpenseCategory(
            name: trimmed,
            systemImage: systemImage,
            colorHex: colorHex,
            sortOrder: nextOrder
        )
        modelContext.insert(category)
        persistAndReload()
    }

    func budget(for categoryId: String) -> Budget? {
        let monthStart = Self.startOfMonth(Date())
        return budgets.first { $0.categoryId == categoryId && $0.periodStart == monthStart }
    }

    func setBudget(categoryId: String, limitAmount: Decimal) {
        error = nil
        guard limitAmount > 0 else {
            error = .invalidAmount
            return
        }
        let monthStart = Self.startOfMonth(Date())
        if let existing = budget(for: categoryId) {
            existing.limitAmount = limitAmount
        } else {
            let budget = Budget(
                categoryId: categoryId,
                periodStart: monthStart,
                limitAmount: limitAmount
            )
            modelContext.insert(budget)
        }
        persistAndReload()
    }

    func removeBudget(_ budget: Budget) {
        modelContext.delete(budget)
        persistAndReload()
    }

    func amountSpent(categoryId: String) -> Decimal {
        let start = Self.startOfMonth(Date())
        return expenseEntries
            .filter {
                $0.isDebit &&
                $0.categoryRef?.id == categoryId &&
                $0.transactionDate >= start
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    func status(for budget: Budget) -> BudgetStatus {
        guard budget.limitAmount > 0 else { return .onTrack }
        let spent = amountSpent(categoryId: budget.categoryId)
        let ratio = NSDecimalNumber(decimal: spent / budget.limitAmount).doubleValue
        if ratio >= 1 { return .over }
        if ratio >= 0.8 { return .approaching }
        return .onTrack
    }

    // MARK: - Persistence

    private func reload() {
        let txnDescriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.transactionDate, order: .reverse)]
        )
        let categoryDescriptor = FetchDescriptor<ExpenseCategory>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let budgetDescriptor = FetchDescriptor<Budget>(
            sortBy: [SortDescriptor(\.periodStart, order: .reverse)]
        )

        do {
            expenseEntries = try modelContext.fetch(txnDescriptor).filter(\.isExpenseTrackerEntry)
            categories = try modelContext.fetch(categoryDescriptor)
            budgets = try modelContext.fetch(budgetDescriptor)
        } catch {
            self.error = .unknownError("We couldn't load your expense data. Please try again.")
        }

        transactionViewModel.loadAllTransactions()
        accountViewModel.loadAccounts()
        hasLoadedOnce = true
    }

    private func persistAndReload() {
        do {
            try modelContext.save()
        } catch {
            self.error = .transactionFailed
        }
        reload()
    }

    private func category(named name: String) -> ExpenseCategory? {
        categories.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private func originalAccount(for transaction: Transaction) -> Account? {
        transaction.account ?? accountViewModel.getAccount(id: transaction.accountId)
    }

    private func applyBalanceChange(to account: Account, amount: Decimal, isIncome: Bool) {
        if isIncome {
            account.balance += amount
            account.availableBalance += amount
        } else {
            account.balance -= amount
            account.availableBalance -= amount
        }
    }

    private func reverseBalanceChange(for transaction: Transaction, on account: Account?) {
        guard let account else { return }
        applyBalanceChange(to: account, amount: transaction.amount, isIncome: transaction.isDebit)
    }

    private static func startOfMonth(_ date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
