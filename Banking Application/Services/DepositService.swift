import Foundation
import SwiftData

/// Credits a matured fixed deposit once, and returns principal when an active deposit is broken.
@MainActor
enum DepositService {
    /// Pays maturity value into the funding account for each active deposit that is due.
    /// `.matured` is the idempotency flag — a later pass does not credit again.
    static func processMatured(in context: ModelContext, now: Date = Date()) {
        guard AuthenticationService.sessionIsLive, !AuthenticationService.movementBlocked else { return }

        let active = FDStatus.active.rawValue
        let due = FetchDescriptor<FixedDeposit>(
            predicate: #Predicate<FixedDeposit> { $0.statusRaw == active && $0.maturityDate <= now }
        )
        let deposits = (try? context.fetch(due)) ?? []
        for deposit in deposits where deposit.status == .active && deposit.maturityDate <= now {
            guard let account = account(id: deposit.sourceAccountId, in: context),
                  account.accountStatus == .active else { continue }

            let amount = deposit.maturityValue
            let previousStatus = deposit.status
            do {
                try Ledger.commit(context, touching: [account]) {
                    Ledger.apply(amount, to: account)
                    deposit.status = .matured
                    credit(
                        account: account,
                        amount: amount,
                        description: "Fixed Deposit matured — \(deposit.nickname)",
                        on: now,
                        in: context
                    )
                }
            } catch {
                // Ledger rolled the context back; make sure the deposit can be retried.
                if deposit.status != previousStatus { deposit.status = previousStatus }
            }
        }
    }

    /// Returns principal only for an active deposit. Already matured or closed deposits are refused.
    static func breakDeposit(_ deposit: FixedDeposit, in context: ModelContext) -> Bool {
        guard AuthenticationService.sessionIsLive, !AuthenticationService.movementBlocked else { return false }
        guard deposit.status == .active else { return false }
        guard let account = account(id: deposit.sourceAccountId, in: context),
              account.accountStatus == .active else { return false }

        let amount = deposit.principal
        let previousStatus = deposit.status
        do {
            try Ledger.commit(context, touching: [account]) {
                Ledger.apply(amount, to: account)
                deposit.status = .closed
                credit(
                    account: account,
                    amount: amount,
                    description: "Fixed Deposit broken — \(deposit.nickname)",
                    on: Date(),
                    in: context
                )
            }
            return true
        } catch {
            if deposit.status != previousStatus { deposit.status = previousStatus }
            return false
        }
    }

    private static func account(id: String, in context: ModelContext) -> Account? {
        var descriptor = FetchDescriptor<Account>(predicate: #Predicate<Account> { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    private static func credit(
        account: Account,
        amount: Decimal,
        description: String,
        on date: Date,
        in context: ModelContext
    ) -> Transaction {
        let transaction = Transaction(
            accountId: account.id,
            type: .deposit,
            amount: amount,
            description: description,
            transactionDate: date,
            category: "Deposit"
        )
        transaction.countsInLedger = true
        transaction.account = account
        context.insert(transaction)
        return transaction
    }
}
