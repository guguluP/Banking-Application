import Foundation
import Combine
import SwiftData

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

        guard !isProcessing else { return false }
        isProcessing = true
        LiveActivityManager.shared.startPayment(kind: "Bill pay", counterparty: biller.displayName, amount: amountDecimal)

        do {
            _ = try TransactionService.post(
                from: account,
                amount: amountDecimal,
                rail: .billPay,
                counterparty: biller.name,
                description: biller.displayName,
                category: "Payment",
                cashbackRate: Self.cashbackRate,
                in: context
            )
            let cashback = (amountDecimal * Self.cashbackRate).rounded(places: 2)
            isProcessing = false
            HapticFeedbackService.shared.success()
            NotificationService.shared.notifyTransaction(
                amount: amountDecimal,
                title: "Bill paid",
                body: "\(CurrencyFormatter.shared.string(from: amountDecimal, currencyCode: account.currency)) paid to \(biller.displayName).",
                remainingBalance: account.availableBalance
            )
            LiveActivityManager.shared.completePayment()
            amount = ""
            lastCashbackEarned = cashback > 0 ? cashback : nil
            return true
        } catch let failure as PaymentFailure {
            isProcessing = false
            error = failure.appError
            HapticFeedbackService.shared.errorOccurred()
            LiveActivityManager.shared.failPayment()
            return false
        } catch {
            isProcessing = false
            self.error = .transactionFailed
            HapticFeedbackService.shared.errorOccurred()
            LiveActivityManager.shared.failPayment()
            return false
        }
    }
}
