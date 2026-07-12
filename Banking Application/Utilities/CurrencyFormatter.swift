import Foundation
import Combine
import SwiftUI

/// Explicitly `nonisolated`: this project defaults new types to main-actor
/// isolation, but `Transaction`/`Account` (SwiftData `@Model` types) call into
/// this formatter from computed properties that must remain callable from
/// whatever isolation context SwiftData uses (including background contexts
/// during CloudKit sync). `NumberFormatter` doesn't require the main actor,
/// so there's no correctness cost to opting out here.
///
/// `@unchecked Sendable`: the only mutable state is `numberFormatter`, which
/// is configured once in `init` and never mutated again — every other method
/// only calls read-only formatting APIs on it. That makes sharing a single
/// instance across threads safe in practice, even though `NumberFormatter`
/// itself isn't marked `Sendable` by Foundation.
nonisolated final class CurrencyFormatter: @unchecked Sendable {
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
