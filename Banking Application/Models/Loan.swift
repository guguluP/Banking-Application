import Foundation
import SwiftData

enum LoanType: String, Codable, CaseIterable {
    case personal = "Personal Loan"
    case home = "Home Loan"
    case auto = "Auto Loan"
    case education = "Education Loan"

    var systemImage: String {
        switch self {
        case .personal: return "person.fill"
        case .home: return "house.fill"
        case .auto: return "car.fill"
        case .education: return "graduationcap.fill"
        }
    }

    /// Illustrative sample rate, not a live/current one — same caveat as
    /// FDRateCard. Real lending rates depend on credit profile, tenure,
    /// and the specific lender's current offers.
    var sampleAnnualRate: Double {
        switch self {
        case .personal: return 11.5
        case .home: return 8.5
        case .auto: return 9.25
        case .education: return 9.75
        }
    }
}

enum LoanStatus: String, Codable {
    case active = "Active"
    case closed = "Closed"
    case foreclosed = "Foreclosed"
}

/// A borrowed loan being repaid via EMI (equated monthly installment) — the
/// reducing-balance repayment method used almost universally in India.
/// Kept separate from Account for the same reason as FixedDeposit: a loan's
/// shape (outstanding principal that only ever goes down, a fixed EMI
/// schedule) doesn't map onto Account's balance/transaction model.
@Model
nonisolated final class Loan {
    var id: String = UUID().uuidString
    var userId: String = ""
    var nickname: String = ""
    var loanTypeRaw: String = LoanType.personal.rawValue
    var principal: Decimal = 0
    var interestRate: Double = 0
    var tenureMonths: Int = 12
    var emiAmount: Decimal = 0
    var outstandingPrincipal: Decimal = 0
    var startDate: Date = Date()
    var nextDueDate: Date = Date()
    var statusRaw: String = LoanStatus.active.rawValue
    var disbursementAccountId: String = ""
    var emisPaid: Int = 0
    var createdAt: Date = Date()

    var loanType: LoanType {
        get { LoanType(rawValue: loanTypeRaw) ?? .personal }
        set { loanTypeRaw = newValue.rawValue }
    }

    var status: LoanStatus {
        get { LoanStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        userId: String,
        nickname: String,
        loanType: LoanType,
        principal: Decimal,
        interestRate: Double,
        tenureMonths: Int,
        emiAmount: Decimal,
        outstandingPrincipal: Decimal,
        startDate: Date = Date(),
        nextDueDate: Date,
        status: LoanStatus = .active,
        disbursementAccountId: String,
        emisPaid: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.nickname = nickname
        self.loanTypeRaw = loanType.rawValue
        self.principal = principal
        self.interestRate = interestRate
        self.tenureMonths = tenureMonths
        self.emiAmount = emiAmount
        self.outstandingPrincipal = outstandingPrincipal
        self.startDate = startDate
        self.nextDueDate = nextDueDate
        self.statusRaw = status.rawValue
        self.disbursementAccountId = disbursementAccountId
        self.emisPaid = emisPaid
        self.createdAt = createdAt
    }

    var remainingEMIs: Int {
        max(0, tenureMonths - emisPaid)
    }

    var progressFraction: Double {
        guard tenureMonths > 0 else { return 1 }
        return min(max(Double(emisPaid) / Double(tenureMonths), 0), 1)
    }

    var totalPaidSoFar: Decimal {
        emiAmount * Decimal(emisPaid)
    }

    var formattedEMI: String {
        CurrencyFormatter.shared.string(from: emiAmount)
    }

    var formattedOutstanding: String {
        CurrencyFormatter.shared.string(from: outstandingPrincipal)
    }
}
