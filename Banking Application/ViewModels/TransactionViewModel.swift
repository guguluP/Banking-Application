import Foundation
import Combine
import SwiftData

@MainActor
class TransactionViewModel: ObservableObject {
    @Published private(set) var transactions: [Transaction] = []
    @Published var isLoading: Bool = false
    @Published var error: AppError?

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadAllTransactions()
    }

    /// Loads every transaction for the signed-in user's accounts. Kept simple
    /// (rather than per-account paging) since this is a local SwiftData store,
    /// not a network round trip — filtering below is effectively free.
    func loadAllTransactions() {
        isLoading = true
        error = nil

        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.transactionDate, order: .reverse)]
        )

        do {
            transactions = try modelContext.fetch(descriptor)
        } catch {
            self.error = .unknownError("We couldn't load your transactions. Please try again.")
        }

        isLoading = false
    }

    func loadTransactions(for accountId: String) {
        loadAllTransactions()
    }

    func getTransactions(for accountId: String) -> [Transaction] {
        transactions.filter { $0.accountId == accountId }
    }

    var recentTransactions: [Transaction] {
        transactions.sorted { $0.transactionDate > $1.transactionDate }
    }

    func getTotalDeposits() -> Decimal {
        transactions.filter { $0.isCredit }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    func getTotalWithdrawals() -> Decimal {
        transactions.filter { !$0.isCredit }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    func clearError() {
        error = nil
    }
}
