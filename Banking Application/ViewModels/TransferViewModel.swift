import Foundation
import Combine
import SwiftData

@MainActor class TransferViewModel: ObservableObject {
    @Published var recipientAccount = ""
    @Published var amount = ""
    @Published var description = ""
    @Published var error: AppError?
    @Published var isProcessing = false
    @Published var searchText = ""

    private static let maxTransferAmount: Decimal = 10_000

    // MARK: - Validation Properties
    var isRecipientValid: Bool {
        let cleaned = recipientAccount.trimmingCharacters(in: .whitespaces)
        return cleaned.count >= 8 && cleaned.count <= 12 && cleaned.allSatisfy({ $0.isNumber })
    }

    var recipientError: String {
        guard !recipientAccount.isEmpty else { return "" }
        let cleaned = recipientAccount.trimmingCharacters(in: .whitespaces)
        if cleaned.count < 8 { return "Account must be at least 8 digits" }
        if cleaned.count > 12 { return "Account must be at most 12 digits" }
        if !cleaned.allSatisfy({ $0.isNumber }) { return "Account must contain only numbers" }
        return ""
    }

    var isAmountValid: Bool {
        guard let amountDecimal = Decimal(string: amount) else { return false }
        return amountDecimal > 0 && amountDecimal <= Self.maxTransferAmount
    }

    var amountError: String {
        guard !amount.isEmpty else { return "" }
        guard let amountDecimal = Decimal(string: amount) else { return "Enter a valid amount" }
        if amountDecimal <= 0 { return "Amount must be greater than zero" }
        if amountDecimal > Self.maxTransferAmount { return "Maximum transfer amount is \(CurrencyFormatter.shared.string(from: Self.maxTransferAmount))" }
        return ""
    }

    var isFormValid: Bool {
        isRecipientValid && isAmountValid
    }

    func validateForm() -> Bool {
        guard isRecipientValid else {
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

    /// Actually moves money, rather than the previous implementation which
    /// only showed a 1.5s spinner and never touched account balances.
    ///
    /// Re-validates recipient/amount/balance here too (not just in the view),
    /// so this method is safe to call from anywhere — including Siri/App
    /// Intents shortcuts — without depending on a particular screen's UI
    /// state for correctness.
    @discardableResult
    func performTransfer(from account: Account, description transferDescription: String, in context: ModelContext) -> Bool {
        guard !isProcessing else { return false }
        clearError()

        guard isRecipientValid else {
            error = .invalidInput
            HapticFeedbackService.shared.errorOccurred()
            return false
        }

        let recipient = recipientAccount.trimmingCharacters(in: .whitespaces)
        guard recipient != account.accountNumber else {
            error = .sameAccount
            HapticFeedbackService.shared.errorOccurred()
            return false
        }

        guard let amountDecimal = Decimal(string: amount), isAmountValid else {
            error = .invalidAmount
            HapticFeedbackService.shared.errorOccurred()
            return false
        }

        // Re-check the balance against the account's *current* value at the
        // moment of execution, not a value captured earlier in the UI — this
        // closes a race where two transfers submitted in quick succession
        // could otherwise both pass an earlier balance check.
        guard amountDecimal <= account.availableBalance else {
            error = .insufficientFunds
            HapticFeedbackService.shared.errorOccurred()
            return false
        }

        isProcessing = true
        let note = transferDescription.trimmingCharacters(in: .whitespaces)
        LiveActivityManager.shared.startPayment(kind: "Transfer", counterparty: recipient, amount: amountDecimal)

        do {
            let receipt = try TransactionService.post(
                from: account,
                amount: amountDecimal,
                rail: .transfer,
                counterparty: recipient,
                description: note.isEmpty ? "Transfer to \(recipient.suffix(4))" : note,
                category: "Transfer",
                recipientAccountNumber: recipient,
                applyRoundUp: true,
                in: context
            )
            isProcessing = false
            HapticFeedbackService.shared.success()
            NotificationService.shared.notifyTransaction(
                amount: amountDecimal,
                title: "Transfer sent",
                body: "\(CurrencyFormatter.shared.string(from: amountDecimal, currencyCode: account.currency)) sent to account ending \(recipient.suffix(4)). Ref \(receipt.reference).",
                remainingBalance: account.availableBalance
            )
            LiveActivityManager.shared.completePayment()
            recipientAccount = ""
            amount = ""
            description = ""
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

extension PaymentFailure {
    var appError: AppError {
        switch self {
        case .invalidAmount, .overSingleCap, .overPeriodLimit: return .invalidAmount
        case .invalidAccountNumber: return .invalidInput
        case .sameAccount: return .sameAccount
        case .insufficientFunds: return .insufficientFunds
        case .notAuthenticated, .movementBlocked: return .authenticationFailed
        case .accountNotMovable, .payeeCoolingOff: return .unknownError(self == .payeeCoolingOff
            ? "This payee is still in the cooling-off period for large transfers."
            : "This account can't send money.")
        case .duplicate, .saveFailed: return .transactionFailed
        }
    }
}
