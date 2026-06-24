import Foundation
import SwiftUI

@MainActor final class CurrencyFormatter {
    static let shared = CurrencyFormatter()
    private let numberFormatter: NumberFormatter
    
    private init() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        self.numberFormatter = formatter
    }
    
    func string(from amount: Decimal, showSign: Bool = false, for transactionType: TransactionType? = nil) -> String {
        let sign = showSign && transactionType != nil && (transactionType == .deposit || transactionType == .interest) ? "+" : ""
        let absAmount = abs(amount)
        let formatted = numberFormatter.string(from: NSDecimalNumber(decimal: absAmount)) ?? "\(absAmount)"
        return sign + formatted
    }
    
    func string(from amount: Decimal) -> String {
        return numberFormatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
    
    func attributedString(from amount: Decimal, showSign: Bool = false, for transactionType: TransactionType? = nil) -> AttributedString {
        let text = string(from: amount, showSign: showSign, for: transactionType)
        return AttributedString(text)
    }
}
