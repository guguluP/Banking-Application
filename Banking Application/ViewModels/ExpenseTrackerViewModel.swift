import Foundation
import SwiftData
import SwiftUI

/// Owns Track-tab expense entries, categories, and budgets. Entries are
/// real `Transaction`s (not a parallel store), so they debit/credit the
/// chosen account the same way a payment would.
@MainActor
@Observable
final class ExpenseTrackerViewModel {

    private(set) var expenseEntries: [Transaction] = []
    private(set) var categories: [ExpenseCategory] = []
    private(set) var budgets: [Budget] = []
    var error: AppError?
    /// True once the deferred initial `reload()` (see `init`) has run at
    /// least once. Lets `TrackView` avoid flashing its "no expenses yet"
    /// empty state for the one frame before that first load completes.
    private(set) var hasLoadedOnce = false

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
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? .distantFuture
        let rows = expenseEntries.filter { $0.transactionDate >= start && $0.transactionDate < end }
        let debits = rows.filter(\.isDebit).reduce(Decimal(0)) { $0 + $1.amount }
        let credits = rows.filter { $0.isCredit && ($0.category ?? "") != "Income" && $0.categoryRef?.name != "Income" }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return max(0, debits - credits)
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
        adjustEnvelope(named: category?.name ?? categoryName, by: isIncome ? -amount : amount)
        persistAndReload()
        noteBudgetThresholds()
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

        let previousName = transaction.category ?? transaction.categoryRef?.name ?? ""
        let previousEffect = transaction.isCredit ? -transaction.amount : transaction.amount
        adjustEnvelope(named: previousName, by: -previousEffect)

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
        adjustEnvelope(named: category?.name ?? categoryName, by: isIncome ? -amount : amount)

        persistAndReload()
        noteBudgetThresholds()
    }

    func deleteExpense(_ transaction: Transaction) {
        error = nil
        reverseBalanceChange(for: transaction, on: originalAccount(for: transaction))
        adjustEnvelope(named: transaction.category ?? transaction.categoryRef?.name ?? "", by: transaction.isCredit ? transaction.amount : -transaction.amount)
        modelContext.delete(transaction)
        persistAndReload()
        noteBudgetThresholds()
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

    func matchesCategory(_ transaction: Transaction, categoryId: String) -> Bool {
        if transaction.categoryRef?.id == categoryId { return true }
        guard transaction.categoryRef == nil, let name = transaction.category else { return false }
        return categories.first { $0.id == categoryId }?.name.caseInsensitiveCompare(name) == .orderedSame
    }

    var uncategorizedThisMonth: [Transaction] {
        let start = Self.startOfMonth(Date())
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? .distantFuture
        return expenseEntries.filter { tx in
            tx.isDebit && tx.countsTowardSpending &&
            tx.transactionDate >= start && tx.transactionDate < end &&
            tx.categoryRef == nil &&
            !categories.contains { $0.name.caseInsensitiveCompare(tx.category ?? "") == .orderedSame }
        }
    }

    var tightestBudget: (category: ExpenseCategory, budget: Budget, status: BudgetStatus)? {
        let ranked = budgets.compactMap { budget -> (ExpenseCategory, Budget, BudgetStatus)? in
            guard let category = categories.first(where: { $0.id == budget.categoryId }) else { return nil }
            let status = status(for: budget)
            guard status != .onTrack else { return nil }
            return (category, budget, status)
        }
        return ranked.max { lhs, rhs in
            amountSpent(categoryId: lhs.1.categoryId) / max(lhs.1.limitAmount, 1)
                < amountSpent(categoryId: rhs.1.categoryId) / max(rhs.1.limitAmount, 1)
        }.map { (category: $0.0, budget: $0.1, status: $0.2) }
    }

    func amountSpent(categoryId: String) -> Decimal {
        let start = Self.startOfMonth(Date())
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? .distantFuture
        let rows = expenseEntries.filter {
            matchesCategory($0, categoryId: categoryId) &&
            $0.transactionDate >= start &&
            $0.transactionDate < end
        }
        let debits = rows.filter(\.isDebit).reduce(Decimal(0)) { $0 + $1.amount }
        let credits = rows.filter { $0.isCredit && $0.categoryRef?.name != "Income" }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return max(0, debits - credits)
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
            let all = try modelContext.fetch(txnDescriptor)
            expenseEntries = all.filter { tx in
                if tx.isCredit { return tx.type != .interest }
                return tx.countsTowardSpending
            }
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

    private func adjustEnvelope(named name: String, by delta: Decimal) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, delta != 0 else { return }
        let envelopes = (try? modelContext.fetch(FetchDescriptor<Envelope>())) ?? []
        guard let envelope = envelopes.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        envelope.spent = max(0, envelope.spent + delta)
    }

    private func noteBudgetThresholds() {
        let defaults = UserDefaults.standard
        for budget in budgets {
            let status = status(for: budget)
            guard status != .onTrack else { continue }
            let key = "budget-noted-\(budget.id)"
            let marker = status == .over ? "over" : "near"
            guard defaults.string(forKey: key) != marker else { continue }
            defaults.set(marker, forKey: key)
            let name = categories.first { $0.id == budget.categoryId }?.name ?? "A category"
            NotificationService.shared.notifyBudget(category: name, overLimit: status == .over)
        }
    }

    private static func startOfMonth(_ date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
