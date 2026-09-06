import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Shared attributes for the payment Live Activity (Lock Screen / Dynamic Island).
/// Kept `nonisolated` to match the app target's copy of this type — see
/// Services/PaymentLiveActivity.swift for why.
nonisolated struct PaymentActivityAttributes: Codable, Hashable, Sendable {
    var paymentKind: String
    var counterparty: String
}

#if canImport(ActivityKit)
extension PaymentActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        var status: String
        var amountText: String
        var isComplete: Bool
    }
}
#endif
