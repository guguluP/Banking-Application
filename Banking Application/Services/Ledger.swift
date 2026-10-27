import Foundation
import OSLog
import SwiftData

/// The one place that moves account balances and persists a money movement.
///
/// `apply` changes book and available balance together. `commit` saves the context;
/// if `changes` throws or the save fails, it deletes the models `changes` inserted,
/// puts the given accounts' balances back to the values they had before `changes`
/// ran, calls `restore` so the caller can put back any other field it edited, and
/// rethrows. Callers only clear their forms or report success after `commit` returns.
///
/// This does not call `ModelContext.rollback()`. Rollback re-reads the rolled-back
/// models from the store's row cache, and a `Decimal` attribute read after that
/// crashes ("Could not cast value of type '__NSCFNumber' to 'NSDecimalNumber'").
/// Undoing by assignment avoids that. A delete cannot be undone that way, so a unit
/// of work that deleted a model is left pending as a whole (balances included, so
/// it stays consistent) and is written by the next successful save.
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

    /// Runs `changes`, then saves. On any thrown error or failed save the changes are undone (see the type comment).
    @discardableResult
    static func commit<Result>(
        _ context: ModelContext,
        touching accounts: [Account] = [],
        restore: () -> Void = {},
        _ changes: () throws -> Result
    ) throws -> Result {
        let snapshots = accounts.map { (account: $0, balance: $0.balance, available: $0.availableBalance) }
        let insertedBefore = pendingInserts(in: context)
        let deletedBefore = context.deletedModelsArray.count
        do {
            let result = try changes()
            try save(context)
            return result
        } catch {
            if context.deletedModelsArray.count > deletedBefore { throw error }
            discardInserts(in: context, except: insertedBefore)
            for snapshot in snapshots {
                snapshot.account.balance = snapshot.balance
                snapshot.account.availableBalance = snapshot.available
            }
            restore()
            throw error
        }
    }

    private static func pendingInserts(in context: ModelContext) -> Set<PersistentIdentifier> {
        Set(context.insertedModelsArray.map { $0.persistentModelID })
    }

    /// Deletes every model inserted since `kept` was taken. A deleted insert is never written.
    private static func discardInserts(in context: ModelContext, except kept: Set<PersistentIdentifier>) {
        for model in context.insertedModelsArray where !kept.contains(model.persistentModelID) {
            // Unlink first so the account's transaction list does not keep the dropped row.
            if let transaction = model as? Transaction { transaction.account = nil }
            context.delete(model)
        }
    }

    private static let log = Logger(subsystem: "BankSecure", category: "Ledger")

    /// For background bookkeeping with no form to report to (seeding, logs,
    /// schedule state). Logs on failure instead of dropping the error; the changes
    /// stay pending and the next successful save writes them.
    @discardableResult
    static func saveOrLog(_ context: ModelContext, _ what: String) -> Bool {
        do {
            try save(context)
            return true
        } catch {
            log.error("Save failed (\(what, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Saves without moving money. On failure the error is rethrown and the changes stay pending.
    /// With `discardingInsertsOnFailure`, models inserted and not yet saved are deleted first,
    /// so a form that is submitted again does not leave a second copy behind.
    static func save(_ context: ModelContext, discardingInsertsOnFailure: Bool = false) throws {
        do {
            if debugFailNextCommit {
                debugFailNextCommit = false
                throw SaveFailed()
            }
            try context.save()
        } catch {
            if discardingInsertsOnFailure { discardInserts(in: context, except: []) }
            throw error
        }
    }
}
