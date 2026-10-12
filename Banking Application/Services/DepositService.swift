import Foundation
import SwiftData

/// Credits a matured fixed deposit once, and returns principal when an active deposit is broken.
@MainActor
enum DepositService {
    /// Pays maturity value into the funding account for each active deposit that is due.
    /// `.matured` is the idempotency flag — a later pass does not credit again.
    static func processMatured(in context: ModelContext, now: Date = Date()) {
        guard AuthenticationService.sessionIsLive, !AuthenticationService.movementBlocked else { return }

        let deposits = (try? context.fetch(FetchDescriptor<FixedDeposit>())) ?? []
        for deposit in deposits where deposit.status == .active && deposit.maturityDate <= now {
            guard let account = account(id: deposit.sourceAccountId, in: context),
                  account.accountStatus == .active else { continue }

            let amount = deposit.maturityValue
            let previousBalance = account.balance
            let previousAvailable = account.availableBalance
            let previousStatus = deposit.status

            account.balance += amount
            account.availableBalance += amount
            deposit.status = .matured

            let transaction = credit(
                account: account,
                amount: amount,
                description: "Fixed Deposit matured — \(deposit.nickname)",
                on: now,
                in: context
            )

            do {
                try context.save()
            } catch {
                account.balance = previousBalance
                account.availableBalance = previousAvailable
                deposit.status = previousStatus
                context.delete(transaction)
                // SwiftData keeps a deleted row on the inverse until the context saves.
                try? context.save()
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
        let previousBalance = account.balance
        let previousAvailable = account.availableBalance
        let previousStatus = deposit.status

        account.balance += amount
        account.availableBalance += amount
        deposit.status = .closed

        let transaction = credit(
            account: account,
            amount: amount,
            description: "Fixed Deposit broken — \(deposit.nickname)",
            on: Date(),
            in: context
        )

        do {
            try context.save()
            return true
        } catch {
            account.balance = previousBalance
            account.availableBalance = previousAvailable
            deposit.status = previousStatus
            context.delete(transaction)
            try? context.save()
            return false
        }
    }

    private static func account(id: String, in context: ModelContext) -> Account? {
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        return accounts.first { $0.id == id }
    }

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
