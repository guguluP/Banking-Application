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
        // Defer the initial load: mutating @Published state synchronously
        // inside init can run during a SwiftUI view update (e.g. when this
        // object is constructed inside another init that's itself building
        // a @StateObject), which triggers "Publishing changes from within
        // view updates is not allowed."
        Task { @MainActor [weak self] in
            self?.loadAllTransactions()
        }
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

    /// Already fetched newest-first in `loadAllTransactions()`.
    var recentTransactions: [Transaction] {
        transactions
    }

    func clearError() {
        error = nil
    }
}
