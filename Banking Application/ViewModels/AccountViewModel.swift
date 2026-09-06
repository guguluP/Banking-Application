import Foundation
import Combine
import SwiftData
import SwiftUI

@MainActor
class AccountViewModel: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var upiTransactions: [UPITransaction] = []
    @Published var weeklySpending: [SpendingDataPoint] = []
    @Published var categoryBreakdown: [CategorySpending] = []
    @Published var isLoading: Bool = false
    @Published var error: AppError?

    /// Natural-language spending summary generated on-device by Apple
    /// Intelligence (Foundation Models). `nil` until `refreshAIInsight()` has
    /// completed, or if the feature is unavailable on this device/OS.
    @Published var aiInsight: String?
    @Published var isGeneratingInsight: Bool = false

    private let modelContext: ModelContext
    private let transactionViewModel: TransactionViewModel

    init(modelContext: ModelContext, transactionViewModel: TransactionViewModel) {
        self.modelContext = modelContext
        self.transactionViewModel = transactionViewModel
        // Deferred for the same reason as TransactionViewModel.init — see
        // that file's comment.
        Task { @MainActor [weak self] in
            self?.loadAccounts()
        }
    }

    var totalBalance: Decimal { accounts.filter { $0.accountType != .credit }.reduce(Decimal(0)) { $0 + $1.balance } }
    var totalAvailableBalance: Decimal { accounts.filter { $0.accountType != .credit }.reduce(Decimal(0)) { $0 + $1.availableBalance } }

    func loadAccounts(userId: String = "user_001") {
        isLoading = true
        error = nil

        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { $0.userId == userId },
            sortBy: [SortDescriptor(\.openedDate)]
        )

        do {
            accounts = try modelContext.fetch(descriptor)
            loadAnalytics()
        } catch {
            // Previously this branch was a no-op comment — failures were
            // silently swallowed and the UI never learned a load had failed.
            self.error = .unknownError("We couldn't load your accounts. Please try again.")
        }

        isLoading = false
    }

    func getAccount(id: String) -> Account? {
        accounts.first { $0.id == id }
    }

    func addUPITransaction(upiId: String, amount: Decimal) {
        let txn = UPITransaction(upiId: upiId, amount: amount, date: Date())
        modelContext.insert(txn)
        do {
            try modelContext.save()
            upiTransactions.insert(txn, at: 0)
            loadAnalytics()
        } catch {
            self.error = .transactionFailed
        }
    }

    func loadAnalytics() {
        weeklySpending = calculateWeeklySpending()
        categoryBreakdown = calculateCategoryBreakdown()
    }

    /// Applies for / issues a new card for the given user. The CVV is
    /// generated locally for the demo card face only — it is `@Transient`
    /// on `Card` and is never persisted (see `Card.cvv`).
    @discardableResult
    func addCard(
        userId: String,
        cardType: CardType,
        cardHolderName: String,
        dailyLimit: Decimal,
        monthlyLimit: Decimal
    ) -> Card? {
        let generatedNumber = String((0..<16).map { _ in String(Int.random(in: 0...9)) }.joined().suffix(4))
        let expiry = Calendar.current.date(byAdding: .year, value: 4, to: Date()) ?? Date()
        let card = Card(
            userId: userId,
            cardNumber: generatedNumber,
            cardType: cardType,
            cardStatus: .active,
            expirationMonth: Calendar.current.component(.month, from: expiry),
            expirationYear: Calendar.current.component(.year, from: expiry),
            cardHolderName: cardHolderName,
            cvv: String(Int.random(in: 100...999)),
            dailyLimit: dailyLimit,
            monthlyLimit: monthlyLimit
        )
        modelContext.insert(card)
        do {
            try modelContext.save()
            return card
        } catch {
            self.error = .transactionFailed
            return nil
        }
    }

    func clearError() {
        error = nil
    }

    private func calculateWeeklySpending() -> [SpendingDataPoint] {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let recentTransactions = transactionViewModel.recentTransactions.filter { $0.transactionDate >= sevenDaysAgo && $0.isDebit }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: recentTransactions) { transaction in
            calendar.startOfDay(for: transaction.transactionDate)
        }

        var dataPoints: [SpendingDataPoint] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let dayStart = calendar.startOfDay(for: date)
                let dayString = dayStart.formatted(.dateTime.weekday(.abbreviated))
                let amount = grouped[dayStart]?.reduce(Decimal(0)) { $0 + $1.amount } ?? Decimal(0)
                dataPoints.append(SpendingDataPoint(day: dayString, amount: amount))
            }
        }

        return dataPoints.reversed()
    }

    private func calculateCategoryBreakdown() -> [CategorySpending] {
        let expenseTransactions = transactionViewModel.recentTransactions.filter { $0.isDebit }

        let grouped = Dictionary(grouping: expenseTransactions) { $0.category ?? "Uncategorized" }

        let categoryColors: [String: Color] = [
            "Groceries": .green,
            "Dining": .orange,
            "Fuel": .red,
            "Income": .blue,
            "Interest": .purple,
            "Transfer": .yellow,
            "Payment": .pink
        ]

        var categorySpending: [CategorySpending] = []
        for (category, transactions) in grouped {
            let totalAmount = transactions.reduce(Decimal(0)) { $0 + $1.amount }
            let color = categoryColors[category] ?? .gray
            categorySpending.append(CategorySpending(name: category, amount: totalAmount, color: color))
        }

        return categorySpending.sorted { $0.amount > $1.amount }
    }

    /// Asks the on-device Apple Intelligence model (Foundation Models) to turn
    /// this week's transactions into a short, friendly summary. Runs entirely
    /// on-device — no transaction data leaves the phone for this feature.
    func refreshAIInsight() async {
        guard !categoryBreakdown.isEmpty else { return }
        isGeneratingInsight = true
        defer { isGeneratingInsight = false }

        do {
            aiInsight = try await AIAssistantService.shared.spendingInsight(
                categories: categoryBreakdown,
                totalAvailableBalance: totalAvailableBalance
            )
        } catch {
            // Non-fatal: the insight card just stays hidden if Apple
            // Intelligence isn't available on this device.
            aiInsight = nil
        }
    }
}
