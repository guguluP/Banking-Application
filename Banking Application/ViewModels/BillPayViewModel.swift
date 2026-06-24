import Foundation
import Combine

class BillPayViewModel: ObservableObject {
    @Published var billerAccount = ""
    @Published var amount = ""
    @Published var error: AppError?
    @Published var isProcessing = false
    @Published var searchText = ""
    
    // MARK: - Validation Properties
    var isBillerValid: Bool {
        let cleaned = billerAccount.trimmingCharacters(in: .whitespaces)
        return !cleaned.isEmpty
    }
    
    var billerError: String {
        guard !billerAccount.isEmpty else { return "" }
        return "" // Basic validation - not empty
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
        return isBillerValid && isAmountValid
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
}