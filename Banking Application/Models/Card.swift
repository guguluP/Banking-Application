import Foundation
import SwiftData

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

@Model
nonisolated final class Card {
    var id: String = UUID().uuidString
    var userId: String = ""

    /// Last four digits only. Full PAN must never be stored on device (PCI-DSS).
    /// Legacy rows that still hold a longer digit string are normalized in
    /// `lastFourDigits` / `maskedCardNumber`.
    var cardNumber: String = ""
    var cardTypeRaw: String = CardType.visa.rawValue
    var cardStatusRaw: String = CardStatus.active.rawValue
    var expirationMonth: Int = 1
    var expirationYear: Int = 2000
    var cardHolderName: String = ""
    var issueDate: Date = Date()
    var dailyLimit: Decimal = 0
    var monthlyLimit: Decimal = 0
    /// Rolling spend counters used for limit progress UI (demo values; a real
    /// issuer would supply these from the card processor).
    var dailySpent: Decimal = 0
    var monthlySpent: Decimal = 0
    var isContactlessEnabled: Bool = true
    var isInternationalUsageEnabled: Bool = false
    var isOnlineTransactionsEnabled: Bool = true

    /// CVV is PCI-DSS "sensitive authentication data": it must NEVER be stored
    /// after authorization. `@Transient` keeps it out of SwiftData and CloudKit.
    @Transient var cvv: String = ""

    var cardType: CardType {
        get { CardType(rawValue: cardTypeRaw) ?? .visa }
        set { cardTypeRaw = newValue.rawValue }
    }

    var cardStatus: CardStatus {
        get { CardStatus(rawValue: cardStatusRaw) ?? .active }
        set { cardStatusRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        userId: String,
        cardNumber: String,
        cardType: CardType,
        cardStatus: CardStatus = .active,
        expirationMonth: Int,
        expirationYear: Int,
        cardHolderName: String,
        cvv: String = "",
        issueDate: Date = Date(),
        dailyLimit: Decimal,
        monthlyLimit: Decimal,
        dailySpent: Decimal = 0,
        monthlySpent: Decimal = 0,
        isContactlessEnabled: Bool = true,
        isInternationalUsageEnabled: Bool = false,
        isOnlineTransactionsEnabled: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.cardNumber = Card.lastFourDigits(from: cardNumber)
        self.cardTypeRaw = cardType.rawValue
        self.cardStatusRaw = cardStatus.rawValue
        self.expirationMonth = expirationMonth
        self.expirationYear = expirationYear
        self.cardHolderName = cardHolderName
        self.cvv = cvv
        self.issueDate = issueDate
        self.dailyLimit = dailyLimit
        self.monthlyLimit = monthlyLimit
        self.dailySpent = dailySpent
        self.monthlySpent = monthlySpent
        self.isContactlessEnabled = isContactlessEnabled
        self.isInternationalUsageEnabled = isInternationalUsageEnabled
        self.isOnlineTransactionsEnabled = isOnlineTransactionsEnabled
    }

    /// Digits only, max 4 characters (last four of a PAN if a longer string is passed).
    static func lastFourDigits(from input: String) -> String {
        let digits = input.filter(\.isNumber)
        guard !digits.isEmpty else { return "••••" }
        return String(digits.suffix(4))
    }

    var lastFourDigits: String {
        Card.lastFourDigits(from: cardNumber)
    }

    var maskedCardNumber: String {
        "•••• •••• •••• \(lastFourDigits)"
    }

    var expirationDate: String {
        String(format: "%02d/%d", expirationMonth, expirationYear % 100)
    }

    var dailyLimitProgress: Double {
        Self.progress(spent: dailySpent, limit: dailyLimit)
    }

    var monthlyLimitProgress: Double {
        Self.progress(spent: monthlySpent, limit: monthlyLimit)
    }

    private static func progress(spent: Decimal, limit: Decimal) -> Double {
        guard limit > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: spent / limit).doubleValue
        return min(max(ratio, 0), 1)
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
