import Foundation
import SwiftData

@MainActor
@Observable
final class FixedDepositViewModel {
    
    var nickname = ""
    var principalText = ""
    var tenureMonths: Int = 12
    var isSeniorCitizen = false
    var error: AppError?

    var principal: Decimal? {
        guard let value = AmountParser.parse(principalText), value > 0 else { return nil }
        return value
    }

    var currentRate: Double {
        FDRateCard.rate(forMonths: tenureMonths, isSeniorCitizen: isSeniorCitizen)
    }

    var tenureLabel: String {
        FDRateCard.label(forMonths: tenureMonths)
    }

    var projectedMaturityValue: Decimal? {
        guard let principal else { return nil }
        return FDRateCard.maturityValue(principal: principal, annualRatePercent: currentRate, months: tenureMonths)
    }

    var projectedInterest: Decimal? {
        guard let principal else { return nil }
        return FDRateCard.interestEarned(principal: principal, annualRatePercent: currentRate, months: tenureMonths)
    }

    var isMinimumMet: Bool {
        guard let principal else { return false }
        return principal >= 1000
    }

    var canOpen: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty && isMinimumMet
    }

    /// Opens the FD and debits the source account's available balance by
    /// the principal — the money has to actually come from somewhere,
    /// same as any other transfer in this app.
    func openDeposit(from sourceAccount: Account, in context: ModelContext) -> Bool {
        guard canOpen, let principal else {
            error = .invalidInput
            return false
        }

        guard sourceAccount.availableBalance >= principal else {
            error = .insufficientFunds
            return false
        }

        let startDate = Date()
        guard let maturityDate = Calendar.current.date(byAdding: .month, value: tenureMonths, to: startDate) else {
            error = .unknownError("Couldn't calculate a maturity date. Try again.")
            return false
        }

        let rate = currentRate
        let maturityValue = FDRateCard.maturityValue(principal: principal, annualRatePercent: rate, months: tenureMonths)

        let deposit = FixedDeposit(
            userId: sourceAccount.userId,
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            principal: principal,
            interestRate: rate,
            tenureMonths: tenureMonths,
            startDate: startDate,
            maturityDate: maturityDate,
            maturityValue: maturityValue,
            sourceAccountId: sourceAccount.id
        )

        let debitTransaction = Transaction(
            accountId: sourceAccount.id,
            type: .payment,
            amount: principal,
            description: "Fixed Deposit — \(deposit.nickname)",
            transactionDate: startDate,
            category: "Savings & Investments"
        )

        do {
            // On failure Ledger deletes the two inserts, so neither the deposit
            // nor the debit survives, and the balance is restored.
            try Ledger.commit(context, touching: [sourceAccount]) {
                Ledger.apply(-principal, to: sourceAccount)
                debitTransaction.countsInLedger = true
                debitTransaction.account = sourceAccount
                context.insert(deposit)
                context.insert(debitTransaction)
            }
            reset()
            return true
        } catch {
            self.error = .unknownError("Couldn't open the deposit. Please try again.")
            return false
        }
    }

    private func reset() {
        nickname = ""
        principalText = ""
        tenureMonths = 12
        isSeniorCitizen = false
    }
}
