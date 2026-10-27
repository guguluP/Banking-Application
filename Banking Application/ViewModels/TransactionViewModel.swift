import Foundation
import SwiftData

@MainActor
@Observable
final class TransactionViewModel {
    private(set) var transactions: [Transaction] = []
    var isLoading: Bool = false
    var error: AppError?

    private let modelContext: ModelContext

    /// - Parameter loadImmediately: the app passes `false` and loads after unlock
    ///   instead, so launch does not fetch the whole history before anyone signs in.
    init(modelContext: ModelContext, loadImmediately: Bool = true) {
        self.modelContext = modelContext
        guard loadImmediately else { return }
        // Defer the initial load: mutating state synchronously
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

    /// Takes rows another owner already fetched newest-first (the Track tab's reload),
    /// so the same full-table query does not run twice in a row.
    func adopt(_ newestFirst: [Transaction]) {
        transactions = newestFirst
        error = nil
    }

    /// Already fetched newest-first in `loadAllTransactions()`.
    var recentTransactions: [Transaction] {
        transactions
    }

    func clearError() {
        error = nil
    }
}
