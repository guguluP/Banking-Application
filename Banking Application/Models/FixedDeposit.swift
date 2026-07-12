import Foundation
import SwiftData

enum FDPayoutType: String, Codable, CaseIterable {
    case cumulative = "Cumulative (Reinvested)"
    case monthly = "Monthly Payout"
    case quarterly = "Quarterly Payout"
}

enum FDStatus: String, Codable {
    case active = "Active"
    case matured = "Matured"
    case closed = "Closed"
}

/// A fixed deposit account. Kept separate from `Account` rather than added
/// as a new `AccountType` case — an FD has a fixed term, a locked principal,
/// and a maturity value that Account's day-to-day balance/transaction model
/// doesn't represent well.
///
/// Persisted locally with SwiftData and CloudKit-eligible for the same
/// reason as Account: every property has a default value, no `.unique`
/// constraints.
@Model
nonisolated final class FixedDeposit {
    var id: String = UUID().uuidString
    var userId: String = ""
    var nickname: String = ""
    var principal: Decimal = 0
    var interestRate: Double = 0
    var tenureMonths: Int = 12
    var payoutTypeRaw: String = FDPayoutType.cumulative.rawValue
    var statusRaw: String = FDStatus.active.rawValue
    var startDate: Date = Date()
    var maturityDate: Date = Date()
    var maturityValue: Decimal = 0
    var sourceAccountId: String = ""
    var createdAt: Date = Date()

    var payoutType: FDPayoutType {
        get { FDPayoutType(rawValue: payoutTypeRaw) ?? .cumulative }
        set { payoutTypeRaw = newValue.rawValue }
    }

    var status: FDStatus {
        get { FDStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        userId: String,
        nickname: String,
        principal: Decimal,
        interestRate: Double,
        tenureMonths: Int,
        payoutType: FDPayoutType = .cumulative,
        status: FDStatus = .active,
        startDate: Date = Date(),
        maturityDate: Date,
        maturityValue: Decimal,
        sourceAccountId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.nickname = nickname
        self.principal = principal
        self.interestRate = interestRate
        self.tenureMonths = tenureMonths
        self.payoutTypeRaw = payoutType.rawValue
        self.statusRaw = status.rawValue
        self.startDate = startDate
        self.maturityDate = maturityDate
        self.maturityValue = maturityValue
        self.sourceAccountId = sourceAccountId
        self.createdAt = createdAt
    }

    /// 0...1 progress toward maturity, for a progress bar.
    var progressFraction: Double {
        let total = maturityDate.timeIntervalSince(startDate)
        guard total > 0 else { return 1 }
        let elapsed = Date().timeIntervalSince(startDate)
        return min(max(elapsed / total, 0), 1)
    }

    /// Linearly-interpolated current value between principal and maturity
    /// value, for display only — the real accrued value depends on the
    /// bank's actual compounding schedule, not shown here.
    var currentEstimatedValue: Decimal {
        guard status == .active else { return maturityValue }
        let fraction = Decimal(progressFraction)
        return principal + (maturityValue - principal) * fraction
    }

    var formattedPrincipal: String {
        CurrencyFormatter.shared.string(from: principal)
    }

    var formattedMaturityValue: String {
        CurrencyFormatter.shared.string(from: maturityValue)
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: maturityDate).day ?? 0)
    }
}
