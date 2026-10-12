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
    case overLimit
    case payeeCooling
    case accountNotMovable
    case destinationNotMovable
    case cardBlocked
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
        case .overLimit: return "overLimit"
        case .payeeCooling: return "payeeCooling"
        case .accountNotMovable: return "accountNotMovable"
        case .destinationNotMovable: return "destinationNotMovable"
        case .cardBlocked: return "cardBlocked"
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
        case .overLimit: return "Over the Limit"
        case .payeeCooling: return "Payee Cooling Off"
        case .accountNotMovable: return "Account Unavailable"
        case .destinationNotMovable: return "Destination Unavailable"
        case .cardBlocked: return "Card Not Available"
        case .unknownError(let message): return message
        }
    }
    
    var message: String {
        switch self {
        case .networkError: return "This action could not be completed with the local demo data. Please try again."
        case .invalidInput: return "Please check your input and try again."
        case .biometricFailed: return "Could not authenticate. Please try again or use your passcode."
        case .insufficientFunds: return "Your account doesn't have enough funds for this transaction."
        case .serverError: return "The server is temporarily unavailable. Please try later."
        case .authenticationFailed: return "Authentication failed. Please try again."
        case .invalidAmount: return "Please enter a valid amount."
        case .sameAccount: return "Please select different accounts."
        case .transactionFailed: return "The transaction could not be completed. Please try again."
        case .overLimit: return "This payment is over the limit for that payment type."
        case .payeeCooling: return "Large payments to a new payee wait until the cooling period ends. Save the payee and try again after that wait."
        case .accountNotMovable: return "This account can't send money."
        case .destinationNotMovable: return "The destination account can't receive money."
        case .cardBlocked: return "UPI and bill pay need an active card with online transactions turned on."
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
        case .overLimit: return "Try a smaller amount, or wait until the daily or monthly limit resets."
        case .payeeCooling: return "Payments under the cooling threshold can still go through."
        case .cardBlocked: return "Unfreeze a card and turn online transactions on, or remove every card to use the demo without one."
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
        case .overLimit: return "gauge.with.dots.needle.67percent"
        case .payeeCooling: return "clock.badge.exclamationmark"
        case .accountNotMovable, .destinationNotMovable: return "lock.fill"
        case .cardBlocked: return "creditcard.trianglebadge.exclamationmark"
        case .unknownError: return "questionmark.circle"
        }
    }
}
