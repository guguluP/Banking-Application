import Foundation
import SwiftData
import Combine

@MainActor
class FixedDepositViewModel: ObservableObject {
    
    @Published var nickname = ""
    @Published var principalText = ""
    @Published var tenureMonths: Int = 12
    @Published var isSeniorCitizen = false
    @Published var error: AppError?

    var principal: Decimal? {
        let cleaned = principalText.replacingOccurrences(of: ",", with: "")
        guard let value = Decimal(string: cleaned), value > 0 else { return nil }
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

        sourceAccount.balance -= principal
        sourceAccount.availableBalance -= principal

        let debitTransaction = Transaction(
            accountId: sourceAccount.id,
            type: .payment,
            amount: principal,
            description: "Fixed Deposit — \(deposit.nickname)",
            transactionDate: startDate,
            category: "Savings & Investments"
        )
        debitTransaction.account = sourceAccount

        context.insert(deposit)
        context.insert(debitTransaction)

        do {
            try context.save()
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
