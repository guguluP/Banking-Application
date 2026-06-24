import SwiftUI

enum AppError: Identifiable {
    case networkError
    case invalidInput
    case biometricFailed
    case insufficientFunds
    case serverError
    case authenticationFailed
    case invalidAmount
    case sameAccount
    case transactionFailed
    case unknownError(String)
    
    var id: String {
        switch self {
        case .unknownError(let message):
            return "unknownError_\(message.hashValue)"
        case .networkError: return "networkError"
        case .invalidInput: return "invalidInput"
        case .biometricFailed: return "biometricFailed"
        case .insufficientFunds: return "insufficientFunds"
        case .serverError: return "serverError"
        case .authenticationFailed: return "authenticationFailed"
        case .invalidAmount: return "invalidAmount"
        case .sameAccount: return "sameAccount"
        case .transactionFailed: return "transactionFailed"
        }
    }
    
    var title: String {
        switch self {
        case .networkError: return "Network Error"
        case .invalidInput: return "Invalid Input"
        case .biometricFailed: return "Biometric Authentication Failed"
        case .insufficientFunds: return "Insufficient Funds"
        case .serverError: return "Server Error"
        case .authenticationFailed: return "Authentication Failed"
        case .invalidAmount: return "Invalid Amount"
        case .sameAccount: return "Same Account"
        case .transactionFailed: return "Transaction Failed"
        case .unknownError(let message): return message
        }
    }
    
    var message: String {
        switch self {
        case .networkError: return "Please check your internet connection and try again."
        case .invalidInput: return "Please check your input and try again."
        case .biometricFailed: return "Could not authenticate. Please try again or use your passcode."
        case .insufficientFunds: return "Your account doesn't have enough funds for this transaction."
        case .serverError: return "The server is temporarily unavailable. Please try later."
        case .authenticationFailed: return "Authentication failed. Please try again."
        case .invalidAmount: return "Please enter a valid amount."
        case .sameAccount: return "Please select different accounts."
        case .transactionFailed: return "The transaction could not be completed. Please try again."
        case .unknownError(let message): return message
        }
    }
    
    var suggestion: String? {
        switch self {
        case .networkError: return "Make sure WiFi or cellular is turned on."
        case .insufficientFunds: return "Check your account balance and try a smaller amount."
        case .biometricFailed: return "Ensure your Face ID or Touch ID is set up correctly."
        case .authenticationFailed: return "Try entering your passcode or check biometric settings."
        case .invalidAmount: return "Enter a valid amount greater than zero."
        default: return nil
        }
    }
    
    var actionTitle: String {
        switch self {
        case .biometricFailed: return "Try Again"
        case .networkError: return "Retry"
        default: return "Dismiss"
        }
    }
    
    var icon: String {
        switch self {
        case .networkError: return "wifi.slash"
        case .invalidInput, .invalidAmount, .sameAccount: return "exclamationmark.circle"
        case .biometricFailed: return "faceid"
        case .insufficientFunds: return "wallet.pass"
        case .serverError: return "server.rack"
        case .authenticationFailed: return "lock.slash"
        case .transactionFailed: return "xmark.circle"
        case .unknownError: return "questionmark.circle"
        }
    }
}
