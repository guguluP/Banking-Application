import Foundation

/// Sample tenure-based FD interest rate slabs, modeled on rates PNB has
/// publicly listed. These are illustrative starting values, not live data —
/// real bank FD rates are revised every few weeks, and a production build
/// needs this wired to an actual rates feed (or backend endpoint) rather
/// than a hardcoded table like this one. Treat this as a placeholder that
/// makes the UI feel real, not a source of truth for actual rates.
enum FDRateCard {
    struct Slab {
        let minMonths: Int
        let maxMonths: Int
        let generalRate: Double
        let seniorCitizenRate: Double
        let label: String
    }

    static let slabs: [Slab] = [
        Slab(minMonths: 1, maxMonths: 2, generalRate: 3.00, seniorCitizenRate: 3.50, label: "7 days – 45 days"),
        Slab(minMonths: 3, maxMonths: 5, generalRate: 4.25, seniorCitizenRate: 4.75, label: "46 – 179 days"),
        Slab(minMonths: 6, maxMonths: 11, generalRate: 5.50, seniorCitizenRate: 6.00, label: "180 days – 1 year"),
        Slab(minMonths: 12, maxMonths: 23, generalRate: 6.40, seniorCitizenRate: 6.90, label: "1 – 2 years"),
        Slab(minMonths: 24, maxMonths: 59, generalRate: 6.10, seniorCitizenRate: 6.60, label: "2 – 5 years"),
        Slab(minMonths: 60, maxMonths: 120, generalRate: 6.00, seniorCitizenRate: 6.50, label: "5 – 10 years")
    ]

    static let availableTenuresMonths = [3, 6, 12, 24, 36, 60, 120]

    static func rate(forMonths months: Int, isSeniorCitizen: Bool = false) -> Double {
        let slab = slabs.first { months >= $0.minMonths && months <= $0.maxMonths } ?? slabs.last!
        return isSeniorCitizen ? slab.seniorCitizenRate : slab.generalRate
    }

    static func label(forMonths months: Int) -> String {
        let slab = slabs.first { months >= $0.minMonths && months <= $0.maxMonths } ?? slabs.last!
        return slab.label
    }

    /// Quarterly-compounded maturity value — the standard method Indian
    /// banks use for cumulative (reinvested-interest) fixed deposits.
    /// A = P(1 + r/n)^(n·t), n = 4 (quarterly).
    static func maturityValue(principal: Decimal, annualRatePercent: Double, months: Int) -> Decimal {
        guard months > 0, annualRatePercent > 0 else { return principal }
        let years = Double(months) / 12.0
        let r = annualRatePercent / 100.0
        let n = 4.0
        let factor = pow(1 + r / n, n * years)
        let principalDouble = NSDecimalNumber(decimal: principal).doubleValue
        let maturityDouble = principalDouble * factor
        // Round to whole paise to avoid a maturity value with more
        // precision than a currency amount should carry.
        return Decimal(round(maturityDouble * 100) / 100)
    }

    static func interestEarned(principal: Decimal, annualRatePercent: Double, months: Int) -> Decimal {
        maturityValue(principal: principal, annualRatePercent: annualRatePercent, months: months) - principal
    }
}
