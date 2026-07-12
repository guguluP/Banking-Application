import Foundation
import Combine
import SwiftData

private extension Decimal {
    /// Rounds to `places` decimal digits (bankers' rounding is unnecessary
    /// here — plain "round half up" matches how currency amounts are
    /// typically displayed to users).
    func rounded(_ places: Int) -> Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, places, .plain)
        return result
    }
}

@MainActor
class BillPayViewModel: ObservableObject {
    @Published var billerAccount = ""
    @Published var amount = ""
    @Published var error: AppError?
    @Published var isProcessing = false
    @Published var searchText = ""

    // MARK: - Validation Properties
    var isBillerValid: Bool {
        !billerAccount.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var billerError: String {
        ""
    }

    var isAmountValid: Bool {
        guard let amountDecimal = Decimal(string: amount) else { return false }
        return amountDecimal > 0
    }

    var amountError: String {
        guard !amount.isEmpty else { return "" }
        guard let amountDecimal = Decimal(string: amount) else { return "Enter a valid amount" }
        if amountDecimal <= 0 { return "Amount must be greater than zero" }
        return ""
    }

    var isFormValid: Bool {
        isBillerValid && isAmountValid
    }

    func validateForm() -> Bool {
        guard isBillerValid else {
            error = .invalidInput
            HapticFeedbackService.shared.errorOccurred()
            return false
        }

        guard isAmountValid else {
            error = .invalidAmount
            HapticFeedbackService.shared.errorOccurred()
            return false
        }

        return true
    }

    func clearError() {
        error = nil
    }

    /// Set right before a successful `payBill` returns, so the view can show
    /// "You earned ₹X cashback" + fire confetti without recomputing anything.
    @Published private(set) var lastCashbackEarned: Decimal?

    private static let cashbackRate: Decimal = 0.01 // 1% — purely a delight feature, not a real loyalty program

    /// Debits the chosen account and records a completed bill payment
    /// transaction. Previously this view model had no execution path at all —
    /// bill payments were validated but never actually applied to a balance.
    @discardableResult
    func payBill(biller: Biller, from account: Account, in context: ModelContext) -> Bool {
        clearError()
        lastCashbackEarned = nil

        guard validateForm() else { return false }
        guard let amountDecimal = Decimal(string: amount) else {
            error = .invalidAmount
            return false
        }

        guard amountDecimal <= account.availableBalance else {
            error = .insufficientFunds
            HapticFeedbackService.shared.errorOccurred()
            return false
        }

        isProcessing = true

        account.balance -= amountDecimal
        account.availableBalance -= amountDecimal

        let txn = Transaction(
            accountId: account.id,
            type: .payment,
            amount: amountDecimal,
            description: biller.displayName,
            counterparty: biller.name,
            transactionDate: Date(),
            category: "Payment",
            status: .completed
        )
        txn.account = account
        context.insert(txn)

        // A small cashback credit, applied to the same account, gives the
        // "you got something back" moment the confetti celebrates.
        let cashback = (amountDecimal * Self.cashbackRate).rounded(2)
        var cashbackTxn: Transaction?
        if cashback > 0 {
            account.balance += cashback
            account.availableBalance += cashback
            let credit = Transaction(
                accountId: account.id,
                type: .deposit,
                amount: cashback,
                description: "Cashback — \(biller.displayName)",
                transactionDate: Date(),
                category: "Cashback",
                status: .completed
            )
            credit.account = account
            context.insert(credit)
            cashbackTxn = credit
        }

        do {
            try context.save()
            isProcessing = false
            HapticFeedbackService.shared.success()
            amount = ""
            lastCashbackEarned = cashback > 0 ? cashback : nil
            return true
        } catch {
            account.balance += amountDecimal
            account.availableBalance += amountDecimal
            context.delete(txn)
            if let cashbackTxn {
                account.balance -= cashback
                account.availableBalance -= cashback
                context.delete(cashbackTxn)
            }
            isProcessing = false
            self.error = .transactionFailed
            HapticFeedbackService.shared.errorOccurred()
            return false
        }
    }
}
