import Foundation
import Combine

@MainActor class TransferViewModel: ObservableObject {
    @Published var recipientAccount = ""
    @Published var amount = ""
    @Published var description = ""
    @Published var error: AppError?
    @Published var isProcessing = false
    @Published var searchText = ""
    
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
        return amountDecimal > 0 && amountDecimal <= 10000
    }
    
    var amountError: String {
        guard !amount.isEmpty else { return "" }
        guard let amountDecimal = Decimal(string: amount) else { return "Enter a valid amount" }
        if amountDecimal <= 0 { return "Amount must be greater than zero" }
        if amountDecimal > 10000 { return "Maximum transfer amount is \(CurrencyFormatter.shared.string(from: 10000))" }
        return ""
    }
    
    var isFormValid: Bool {
        return isRecipientValid && isAmountValid
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
}
