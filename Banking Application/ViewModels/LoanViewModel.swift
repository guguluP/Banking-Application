import Foundation
import SwiftData

@MainActor
@Observable
class LoanViewModel {
    var nickname = ""
    var loanType: LoanType = .personal
    var principalText = ""
    var tenureMonths: Int = 24
    var error: AppError?

    var principal: Decimal? {
        let cleaned = principalText.replacingOccurrences(of: ",", with: "")
        guard let value = Decimal(string: cleaned), value > 0 else { return nil }
        return value
    }

    var currentRate: Double {
        loanType.sampleAnnualRate
    }

    var projectedEMI: Decimal? {
        guard let principal else { return nil }
        return LoanCalculator.monthlyEMI(principal: principal, annualRatePercent: currentRate, months: tenureMonths)
    }

    var projectedTotalInterest: Decimal? {
        guard let principal else { return nil }
        return LoanCalculator.totalInterest(principal: principal, annualRatePercent: currentRate, months: tenureMonths)
    }

    var isMinimumMet: Bool {
        guard let principal else { return false }
        return principal >= 10000
    }

    var canApply: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty && isMinimumMet
    }

    /// Takes out a new loan: credits the disbursement account with the
    /// principal and creates the Loan record. Mirrors how opening a fixed
    /// deposit actually debits an account rather than just being cosmetic.
    func applyForLoan(disbursingTo account: Account, in context: ModelContext) -> Bool {
        guard canApply, let principal else {
            error = .invalidInput
            return false
        }

        let emi = LoanCalculator.monthlyEMI(principal: principal, annualRatePercent: currentRate, months: tenureMonths)
        let startDate = Date()
        guard let nextDueDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) else {
            error = .unknownError("Couldn't calculate the first due date. Try again.")
            return false
        }

        let loan = Loan(
            userId: account.userId,
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            loanType: loanType,
            principal: principal,
            interestRate: currentRate,
            tenureMonths: tenureMonths,
            emiAmount: emi,
            outstandingPrincipal: principal,
            startDate: startDate,
            nextDueDate: nextDueDate,
            disbursementAccountId: account.id
        )

        account.balance += principal
        account.availableBalance += principal

        let creditTransaction = Transaction(
            accountId: account.id,
            type: .deposit,
            amount: principal,
            description: "\(loanType.rawValue) Disbursement — \(loan.nickname)",
            transactionDate: startDate,
            category: "Loans"
        )
        creditTransaction.countsInLedger = true
        creditTransaction.account = account

        context.insert(loan)
        context.insert(creditTransaction)

        do {
            try context.save()
            reset()
            return true
        } catch {
            // Roll back the disbursement credit and remove the inserted
            // objects if persistence failed, mirroring FixedDepositViewModel.
            account.balance -= principal
            account.availableBalance -= principal
            context.delete(loan)
            context.delete(creditTransaction)
            self.error = .unknownError("Couldn't process the loan. Please try again.")
            return false
        }
    }

    /// Debits the smaller of the EMI and the remaining principal plus this
    /// month's interest. The loan closes when outstanding principal hits zero.
    func payEMI(for loan: Loan, from account: Account, in context: ModelContext) -> Bool {
        guard AuthenticationService.sessionIsLive, !AuthenticationService.movementBlocked else {
            error = .authenticationFailed
            return false
        }
        guard loan.status == .active, loan.outstandingPrincipal > 0 else {
            error = .transactionFailed
            return false
        }
        guard account.accountStatus == .active else {
            error = .transactionFailed
            return false
        }

        let monthlyRate = loan.interestRate / 100.0 / 12.0
        let balanceDouble = NSDecimalNumber(decimal: loan.outstandingPrincipal).doubleValue
        let interestPortion = Decimal(round(balanceDouble * monthlyRate * 100) / 100)
        let obligation = loan.outstandingPrincipal + interestPortion
        let paysOff = obligation <= loan.emiAmount
        let debitAmount = paysOff ? obligation : loan.emiAmount
        let principalPortion = paysOff
            ? loan.outstandingPrincipal
            : min(max(debitAmount - interestPortion, 0), loan.outstandingPrincipal)

        guard debitAmount > 0 else {
            error = .invalidInput
            return false
        }
        guard account.availableBalance >= debitAmount else {
            error = .insufficientFunds
            return false
        }

        account.balance -= debitAmount
        account.availableBalance -= debitAmount

        // Captured so a failed save can restore the loan to exactly where it was.
        let previousOutstandingPrincipal = loan.outstandingPrincipal
        let previousEmisPaid = loan.emisPaid
        let previousNextDueDate = loan.nextDueDate
        let previousStatus = loan.status

        loan.outstandingPrincipal = max(0, loan.outstandingPrincipal - principalPortion)
        loan.emisPaid += 1
        if loan.outstandingPrincipal <= 0 {
            loan.outstandingPrincipal = 0
            loan.status = .closed
        } else {
            loan.nextDueDate = Calendar.current.date(byAdding: .month, value: 1, to: loan.nextDueDate) ?? loan.nextDueDate
        }

        let debitTransaction = Transaction(
            accountId: account.id,
            type: .payment,
            amount: debitAmount,
            description: "EMI — \(loan.nickname)",
            transactionDate: Date(),
            category: "Loans"
        )
        debitTransaction.countsInLedger = true
        debitTransaction.account = account

        context.insert(debitTransaction)

        do {
            try context.save()
            error = nil
            return true
        } catch {
            // Roll back the actual debit and the loan schedule mutation if
            // persistence failed, so the EMI never appears paid when it wasn't saved.
            account.balance += debitAmount
            account.availableBalance += debitAmount
            loan.outstandingPrincipal = previousOutstandingPrincipal
            loan.emisPaid = previousEmisPaid
            loan.nextDueDate = previousNextDueDate
            loan.status = previousStatus
            context.delete(debitTransaction)
            self.error = .unknownError("Couldn't process the EMI payment. Please try again.")
            return false
        }
    }

    /// Pays down principal and keeps the EMI. Tenure shrinks to the months
    /// still needed to clear the new balance. A zero balance closes the loan.
    func prepay(_ amount: Decimal, for loan: Loan, from account: Account, in context: ModelContext) -> Bool {
        guard AuthenticationService.sessionIsLive, !AuthenticationService.movementBlocked else {
            error = .authenticationFailed
            return false
        }
        guard loan.status == .active, loan.outstandingPrincipal > 0 else {
            error = .transactionFailed
            return false
        }
        guard account.accountStatus == .active else {
            error = .transactionFailed
            return false
        }
        guard amount > 0, amount <= loan.outstandingPrincipal else {
            error = .invalidInput
            return false
        }
        guard account.availableBalance >= amount else {
            error = .insufficientFunds
            return false
        }

        account.balance -= amount
        account.availableBalance -= amount

        // Captured so a failed save can restore the loan to exactly where it was.
        let previousOutstandingPrincipal = loan.outstandingPrincipal
        let previousStatus = loan.status
        let previousTenureMonths = loan.tenureMonths

        loan.outstandingPrincipal -= amount

        if loan.outstandingPrincipal <= 0 {
            loan.outstandingPrincipal = 0
            loan.status = .closed
        } else {
            let monthlyRate = loan.interestRate / 100.0 / 12.0
            let months = LoanCalculator.monthsToPayoff(
                balance: loan.outstandingPrincipal,
                monthlyRate: monthlyRate,
                emi: loan.emiAmount
            )
            loan.tenureMonths = loan.emisPaid + months
        }

        let debitTransaction = Transaction(
            accountId: account.id,
            type: .payment,
            amount: amount,
            description: "Prepayment — \(loan.nickname)",
            transactionDate: Date(),
            category: "Loans"
        )
        debitTransaction.countsInLedger = true
        debitTransaction.account = account
        context.insert(debitTransaction)

        do {
            try context.save()
            error = nil
            return true
        } catch {
            // Roll back the debit and the loan mutation if persistence
            // failed, so the prepayment never appears applied when it wasn't saved.
            account.balance += amount
            account.availableBalance += amount
            loan.outstandingPrincipal = previousOutstandingPrincipal
            loan.status = previousStatus
            loan.tenureMonths = previousTenureMonths
            context.delete(debitTransaction)
            self.error = .unknownError("Couldn't process the prepayment. Please try again.")
            return false
        }
    }

    private func reset() {
        nickname = ""
        principalText = ""
        tenureMonths = 24
        loanType = .personal
    }
}

