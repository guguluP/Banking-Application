import Foundation
import SwiftData

/// The one place that moves account balances and persists a money movement.
///
/// `apply` changes book and available balance together. `commit` saves the context; if
/// the save fails it calls `ModelContext.rollback()`, which discards every unsaved
/// insert, delete and edit in that context, then puts the given accounts' balances back
/// to the values they had before `changes` ran, and rethrows. Callers only clear their
/// forms or report success after `commit` returns.
@MainActor
enum Ledger {
    /// Test hook: the next `commit` fails as if the store had refused the save.
    static var debugFailNextCommit = false

    struct SaveFailed: Error {}

    /// Positive `delta` credits the account, negative debits it.
    static func apply(_ delta: Decimal, to account: Account) {
        account.balance += delta
        account.availableBalance += delta
    }

    /// Runs `changes`, then saves. On any thrown error or failed save the context is rolled back.
    @discardableResult
    static func commit<Result>(
        _ context: ModelContext,
        touching accounts: [Account] = [],
        _ changes: () throws -> Result
    ) throws -> Result {
        let snapshots = accounts.map { (account: $0, balance: $0.balance, available: $0.availableBalance) }
        do {
            let result = try changes()
            try save(context)
            return result
        } catch {
            context.rollback()
            for snapshot in snapshots {
                if snapshot.account.balance != snapshot.balance { snapshot.account.balance = snapshot.balance }
                if snapshot.account.availableBalance != snapshot.available { snapshot.account.availableBalance = snapshot.available }
            }
            throw error
        }
    }

    /// Saves without moving money. On failure the context is rolled back and the error rethrown.
    static func save(_ context: ModelContext, rollbackOnFailure: Bool = false) throws {
        do {
            if debugFailNextCommit {
                debugFailNextCommit = false
                throw SaveFailed()
            }
            try context.save()
        } catch {
            if rollbackOnFailure { context.rollback() }
            throw error
        }
    }
}
