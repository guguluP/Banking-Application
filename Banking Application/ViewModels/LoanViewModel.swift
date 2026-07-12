import Foundation
import SwiftData
import Combine

@MainActor
class LoanViewModel: ObservableObject {
    @Published var nickname = ""
    @Published var loanType: LoanType = .personal
    @Published var principalText = ""
    @Published var tenureMonths: Int = 24
    @Published var error: AppError?

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
        creditTransaction.account = account

        context.insert(loan)
        context.insert(creditTransaction)

        do {
            try context.save()
            reset()
            return true
        } catch {
            self.error = .unknownError("Couldn't process the loan. Please try again.")
            return false
        }
    }

    /// Pays the next scheduled EMI: splits it into principal/interest at
    /// the loan's current outstanding balance, debits the source account,
    /// and advances the schedule by one month.
    func payEMI(for loan: Loan, from account: Account, in context: ModelContext) -> Bool {
        guard loan.status == .active, loan.remainingEMIs > 0 else { return false }
        guard account.availableBalance >= loan.emiAmount else {
            error = .insufficientFunds
            return false
        }

        let monthlyRate = loan.interestRate / 100.0 / 12.0
        let balanceDouble = NSDecimalNumber(decimal: loan.outstandingPrincipal).doubleValue
        let interestPortion = Decimal(round(balanceDouble * monthlyRate * 100) / 100)
        var principalPortion = loan.emiAmount - interestPortion
        if loan.remainingEMIs == 1 {
            principalPortion = loan.outstandingPrincipal
        }

        account.balance -= loan.emiAmount
        account.availableBalance -= loan.emiAmount

        loan.outstandingPrincipal = max(0, loan.outstandingPrincipal - principalPortion)
        loan.emisPaid += 1
        if loan.remainingEMIs > 0 {
            loan.nextDueDate = Calendar.current.date(byAdding: .month, value: 1, to: loan.nextDueDate) ?? loan.nextDueDate
        } else {
            loan.status = .closed
        }

        let debitTransaction = Transaction(
            accountId: account.id,
            type: .payment,
            amount: loan.emiAmount,
            description: "EMI — \(loan.nickname)",
            transactionDate: Date(),
            category: "Loans"
        )
        debitTransaction.account = account

        context.insert(debitTransaction)

        do {
            try context.save()
            return true
        } catch {
            self.error = .unknownError("Couldn't process the EMI payment. Please try again.")
            return false
        }
    }

    /// Applies a lump-sum prepayment against outstanding principal, debits
    /// the account, and reduces the balance immediately. Tenure/EMI display
    /// updates on the next read since remainingEMIs is derived from
    /// outstandingPrincipal changes indirectly via emisPaid — the schedule
    /// itself isn't rewritten, matching how real prepayments typically
    /// keep the EMI fixed and shorten the tail instead.
    func prepay(_ amount: Decimal, for loan: Loan, from account: Account, in context: ModelContext) -> Bool {
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
        loan.outstandingPrincipal -= amount

        if loan.outstandingPrincipal <= 0 {
            loan.status = .closed
        }

        let debitTransaction = Transaction(
            accountId: account.id,
            type: .payment,
            amount: amount,
            description: "Prepayment — \(loan.nickname)",
            transactionDate: Date(),
            category: "Loans"
        )
        debitTransaction.account = account
        context.insert(debitTransaction)

        do {
            try context.save()
            return true
        } catch {
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

