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
    /// Bumped on every reload so views that cache derived rows know to rebuild.
    private(set) var revision = 0

    // Aggregates are computed once per `reload()` instead of on every render.
    private(set) var amountSpentThisMonth: Decimal = 0
    private(set) var uncategorizedThisMonth: [Transaction] = []
    private(set) var tightestBudget: (category: ExpenseCategory, budget: Budget, status: BudgetStatus)?
    private(set) var recurringSpend: [FinancialIntelligenceService.RecurringCandidate] = []
    private var spentThisMonthByCategoryId: [String: Decimal] = [:]
    /// Lowercased search text per entry id, built once per reload.
    private var searchHaystacks: [String: String] = [:]

    private let modelContext: ModelContext
    /// Envelopes for the current edit; cleared on every reload.
    @ObservationIgnored private var envelopeCache: [Envelope]?
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

    func filteredEntries(searchText: String, categoryId: String? = nil) -> [Transaction] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty && categoryId == nil { return expenseEntries }
        return expenseEntries.filter { entry in
            if let categoryId, entry.categoryRef?.id != categoryId {
                return false
            }
            guard !query.isEmpty else { return true }
            return (searchHaystacks[entry.id] ?? Self.searchHaystack(for: entry)).contains(query)
        }
    }

    private static func searchHaystack(for entry: Transaction) -> String {
        [
            entry.merchant,
            entry.transactionDescription,
            entry.notes,
            entry.categoryRef?.name,
            entry.category,
            entry.account?.expenseAccountLabel
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")
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

        if !isIncome, !account.isDeclaredSpendAccount, amount > account.availableBalance {
            error = .insufficientFunds
            return
        }

        let category = category(named: categoryName)
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
        commitAndReload(touching: [account]) {
            if !account.isDeclaredSpendAccount {
                applyBalanceChange(to: account, amount: amount, isIncome: isIncome)
            }
            txn.account = account
            txn.countsInLedger = !account.isDeclaredSpendAccount
            modelContext.insert(txn)
            adjustEnvelope(named: category?.name ?? categoryName, by: isIncome ? -amount : amount)
        }
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

        let original = originalAccount(for: transaction)
        let category = category(named: categoryName)
        commitAndReload(touching: [original, account]) {
            if original?.isDeclaredSpendAccount != true {
                reverseBalanceChange(for: transaction, on: original)
            }

            if !isIncome, !account.isDeclaredSpendAccount, amount > account.availableBalance {
                // Thrown inside the commit so the reversal above is rolled back with it.
                throw InsufficientFundsForEdit()
            }

            if !account.isDeclaredSpendAccount {
                applyBalanceChange(to: account, amount: amount, isIncome: isIncome)
            }

            let previousName = transaction.category ?? transaction.categoryRef?.name ?? ""
            let previousEffect = transaction.isCredit ? -transaction.amount : transaction.amount
            adjustEnvelope(named: previousName, by: -previousEffect)

            transaction.accountId = account.id
            transaction.account = account
            transaction.countsInLedger = !account.isDeclaredSpendAccount
            transaction.type = isIncome ? .deposit : .payment
            transaction.amount = amount
            transaction.merchant = merchant
            transaction.counterparty = merchant
            transaction.transactionDescription = description
            transaction.category = category?.name ?? categoryName
            transaction.categoryRef = category
            transaction.transactionDate = date
            adjustEnvelope(named: category?.name ?? categoryName, by: isIncome ? -amount : amount)
        }
        if error == nil { noteBudgetThresholds() }
    }

    func deleteExpense(_ transaction: Transaction) {
        error = nil
        let original = originalAccount(for: transaction)
        commitAndReload(touching: [original]) {
            if original?.isDeclaredSpendAccount != true {
                reverseBalanceChange(for: transaction, on: original)
            }
            adjustEnvelope(named: transaction.category ?? transaction.categoryRef?.name ?? "", by: transaction.isCredit ? transaction.amount : -transaction.amount)
            modelContext.delete(transaction)
        }
        noteBudgetThresholds()
    }

    func wipeAllTrackerData() {
        error = nil
        let touched = expenseEntries.map { originalAccount(for: $0) }
        commitAndReload(touching: touched) {
            for entry in expenseEntries {
                let original = originalAccount(for: entry)
                if original?.isDeclaredSpendAccount != true {
                    reverseBalanceChange(for: entry, on: original)
                }
                modelContext.delete(entry)
            }
            for budget in budgets {
                modelContext.delete(budget)
            }
            for category in categories where !category.isBuiltIn {
                modelContext.delete(category)
            }
        }
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

    /// This month's net spend for the category, from the totals built in `reload()`.
    func amountSpent(categoryId: String) -> Decimal {
        spentThisMonthByCategoryId[categoryId] ?? 0
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

    func reload() {
        envelopeCache = nil
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
            let storedAccounts = (try? modelContext.fetch(FetchDescriptor<Account>())) ?? []
            let declared = storedAccounts.filter(\.isDeclaredSpendAccount)
            expenseEntries = all.filter { tx in
                if !declared.isEmpty {
                    let bank = tx.account?.bankName ?? declared.first { $0.id == tx.accountId }?.bankName ?? ""
                    guard !bank.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                }
                if tx.isCredit { return tx.type != .interest }
                return tx.countsTowardSpending
            }
            categories = try modelContext.fetch(categoryDescriptor)
            budgets = try modelContext.fetch(budgetDescriptor)
            // Home shares this fetch instead of running the same full-table query again.
            transactionViewModel.adopt(all)
        } catch {
            self.error = .unknownError("We couldn't load your expense data. Please try again.")
            transactionViewModel.loadAllTransactions()
        }

        recomputeAggregates()
        accountViewModel.loadAccounts()
        hasLoadedOnce = true
        revision &+= 1
    }

    /// One pass over this month's entries for every total the Track tab shows.
    private func recomputeAggregates(now: Date = Date()) {
        let start = Self.startOfMonth(now)
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? .distantFuture

        var categoryIdsByName: [String: [String]] = [:]
        for category in categories {
            categoryIdsByName[category.name.lowercased(), default: []].append(category.id)
        }

        var monthDebits: Decimal = 0
        var monthCredits: Decimal = 0
        var debitsByCategory: [String: Decimal] = [:]
        var creditsByCategory: [String: Decimal] = [:]
        var uncategorized: [Transaction] = []
        var haystacks: [String: String] = [:]
        haystacks.reserveCapacity(expenseEntries.count)

        for tx in expenseEntries {
            haystacks[tx.id] = Self.searchHaystack(for: tx)
            guard tx.transactionDate >= start && tx.transactionDate < end else { continue }

            let categoryName = tx.categoryRef?.name
            if tx.isDebit {
                monthDebits += tx.amount
            } else if tx.isCredit && (tx.category ?? "") != "Income" && categoryName != "Income" {
                monthCredits += tx.amount
            }

            // Same rule as `matchesCategory`: the linked category, or a legacy name match.
            let matchedIds: [String]
            if let ref = tx.categoryRef {
                matchedIds = [ref.id]
            } else if let name = tx.category {
                matchedIds = categoryIdsByName[name.lowercased()] ?? []
            } else {
                matchedIds = []
            }
            for id in matchedIds {
                if tx.isDebit {
                    debitsByCategory[id, default: 0] += tx.amount
                } else if tx.isCredit && categoryName != "Income" {
                    creditsByCategory[id, default: 0] += tx.amount
                }
            }

            if tx.isDebit && tx.countsTowardSpending && tx.categoryRef == nil
                && categoryIdsByName[(tx.category ?? "").lowercased()] == nil {
                uncategorized.append(tx)
            }
        }

        var spent: [String: Decimal] = [:]
        for id in Set(debitsByCategory.keys).union(creditsByCategory.keys) {
            spent[id] = max(0, (debitsByCategory[id] ?? 0) - (creditsByCategory[id] ?? 0))
        }

        amountSpentThisMonth = max(0, monthDebits - monthCredits)
        spentThisMonthByCategoryId = spent
        uncategorizedThisMonth = uncategorized
        searchHaystacks = haystacks
        recurringSpend = FinancialIntelligenceService.detectRecurring(transactions: expenseEntries.filter(\.countsTowardSpending))

        let categoriesById = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var tightest: (category: ExpenseCategory, budget: Budget, status: BudgetStatus, ratio: Decimal)?
        for budget in budgets {
            guard let category = categoriesById[budget.categoryId] else { continue }
            let status = status(for: budget)
            guard status != .onTrack else { continue }
            let ratio = amountSpent(categoryId: budget.categoryId) / max(budget.limitAmount, 1)
            // `max(by:)` keeps the last of equal elements; `>=` does the same.
            if tightest == nil || ratio >= tightest!.ratio {
                tightest = (category, budget, status, ratio)
            }
        }
        tightestBudget = tightest.map { (category: $0.category, budget: $0.budget, status: $0.status) }
    }

    /// Runs `changes` and saves through `Ledger`. A failed save rolls back the context
    /// (including any balance moved inside `changes`) and sets `error`. Always reloads.
    private func commitAndReload(touching accounts: [Account?], _ changes: () throws -> Void) {
        do {
            try Ledger.commit(modelContext, touching: accounts.compactMap { $0 }, changes)
        } catch is InsufficientFundsForEdit {
            self.error = .insufficientFunds
        } catch {
            self.error = .transactionFailed
        }
        reload()
    }

    /// Saves a change that does not move money. Rolls back on failure.
    private func persistAndReload() {
        do {
            try Ledger.save(modelContext, rollbackOnFailure: true)
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
        Ledger.apply(isIncome ? amount : -amount, to: account)
    }

    private func reverseBalanceChange(for transaction: Transaction, on account: Account?) {
        guard let account else { return }
        applyBalanceChange(to: account, amount: transaction.amount, isIncome: transaction.isDebit)
    }

    private func adjustEnvelope(named name: String, by delta: Decimal) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, delta != 0 else { return }
        if envelopeCache == nil {
            envelopeCache = (try? modelContext.fetch(FetchDescriptor<Envelope>())) ?? []
        }
        guard let envelope = envelopeCache?.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
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

    private struct InsufficientFundsForEdit: Error {}

    private static func startOfMonth(_ date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
