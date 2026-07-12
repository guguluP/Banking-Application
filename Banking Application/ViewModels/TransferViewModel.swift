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

        account.balance -= amountDecimal
        account.availableBalance -= amountDecimal

        let note = transferDescription.trimmingCharacters(in: .whitespaces)
        let txn = Transaction(
            accountId: account.id,
            type: .transfer,
            amount: amountDecimal,
            description: note.isEmpty ? "Transfer to \(recipient.suffix(4))" : note,
            counterparty: recipient,
            transactionDate: Date(),
            category: "Transfer",
            status: .completed
        )
        txn.account = account
        context.insert(txn)

        do {
            try context.save()
            isProcessing = false
            HapticFeedbackService.shared.success()
            recipientAccount = ""
            amount = ""
            description = ""
            return true
        } catch {
            // Roll back the in-memory balance change if persistence failed,
            // so the UI never shows money as "sent" when it wasn't saved.
            account.balance += amountDecimal
            account.availableBalance += amountDecimal
            context.delete(txn)
            isProcessing = false
            self.error = .transactionFailed
            HapticFeedbackService.shared.errorOccurred()
            return false
        }
    }
}
