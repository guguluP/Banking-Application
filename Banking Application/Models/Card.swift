import Foundation

enum CardType: String, Codable, CaseIterable {
    case visa = "Visa"
    case mastercard = "Mastercard"
    case amex = "American Express"
    case discover = "Discover"
    case debit = "Debit"
}

enum CardStatus: String, Codable {
    case active = "Active"
    case inactive = "Inactive"
    case blocked = "Blocked"
    case expired = "Expired"
    case lostStolen = "Lost/Stolen"
}

struct Card: Identifiable, Codable {
    let id: String
    let userId: String
    let cardNumber: String
    let cardType: CardType
    let cardStatus: CardStatus
    let expirationMonth: Int
    let expirationYear: Int
    let cardHolderName: String
    let cvv: String
    let issueDate: Date
    var dailyLimit: Decimal
    var monthlyLimit: Decimal
    var isContactlessEnabled: Bool
    var isInternationalUsageEnabled: Bool
    var isOnlineTransactionsEnabled: Bool
    
    var maskedCardNumber: String {
        let lastFour = String(cardNumber.suffix(4))
        return "•••• •••• •••• \(lastFour)"
    }
    
    var expirationDate: String {
        return String(format: "%02d/%d", expirationMonth, expirationYear % 100)
    }
    
    var isExpired: Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        if expirationYear < currentYear {
            return true
        } else if expirationYear == currentYear && expirationMonth < currentMonth {
            return true
        }
        return false
    }
}