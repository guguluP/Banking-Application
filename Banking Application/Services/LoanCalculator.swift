import Foundation

/// EMI (equated monthly installment) math for reducing-balance loans — the
/// standard repayment method for personal, home, auto, and education loans
/// in India. Rates in LoanType.sampleAnnualRate are illustrative, same
/// caveat as FDRateCard: not live, a placeholder until wired to a real
/// rates source.
enum LoanCalculator {
    struct ScheduleRow: Identifiable {
        let id: Int
        let month: Int
        let emi: Decimal
        let principalPortion: Decimal
        let interestPortion: Decimal
        let remainingBalance: Decimal
    }

    /// EMI = P × r × (1+r)^n / ((1+r)^n − 1), r = monthly rate.
    static func monthlyEMI(principal: Decimal, annualRatePercent: Double, months: Int) -> Decimal {
        guard months > 0 else { return principal }
        guard annualRatePercent > 0 else {
            return (principal / Decimal(months)).rounded(scale: 2)
        }

        let p = NSDecimalNumber(decimal: principal).doubleValue
        let r = annualRatePercent / 100.0 / 12.0
        let n = Double(months)
        let factor = pow(1 + r, n)
        let emi = p * r * factor / (factor - 1)
        return Decimal(round(emi * 100) / 100)
    }

    static func totalInterest(principal: Decimal, annualRatePercent: Double, months: Int) -> Decimal {
        let emi = monthlyEMI(principal: principal, annualRatePercent: annualRatePercent, months: months)
        return (emi * Decimal(months)) - principal
    }

    /// Full month-by-month principal/interest split, for a repayment
    /// schedule screen. Capped at 600 rows (50 years) as a sanity bound.
    static func amortizationSchedule(principal: Decimal, annualRatePercent: Double, months: Int) -> [ScheduleRow] {
        guard months > 0, months <= 600 else { return [] }
        let emi = monthlyEMI(principal: principal, annualRatePercent: annualRatePercent, months: months)
        let monthlyRate = annualRatePercent / 100.0 / 12.0

        var rows: [ScheduleRow] = []
        var balance = principal

        for month in 1...months {
            let interestPortion: Decimal
            if monthlyRate > 0 {
                let balanceDouble = NSDecimalNumber(decimal: balance).doubleValue
                interestPortion = Decimal(round(balanceDouble * monthlyRate * 100) / 100)
            } else {
                interestPortion = 0
            }
            var principalPortion = emi - interestPortion
            if month == months {
                // Last installment absorbs any rounding drift so the
                // schedule lands exactly on zero instead of a few paise off.
                principalPortion = balance
            }
            balance = max(0, balance - principalPortion)

            rows.append(ScheduleRow(
                id: month,
                month: month,
                emi: emi,
                principalPortion: principalPortion,
                interestPortion: interestPortion,
                remainingBalance: balance
            ))
        }
        return rows
    }

    /// Interest saved by making a lump-sum prepayment today against the
    /// current outstanding balance, keeping the EMI fixed and shortening
    /// the remaining tenure instead (the more common prepayment structure
    /// Indian lenders offer, versus recalculating a lower EMI).
    static func prepaymentImpact(
        outstandingPrincipal: Decimal,
        annualRatePercent: Double,
        currentEMI: Decimal,
        prepaymentAmount: Decimal
    ) -> (newRemainingMonths: Int, interestSaved: Decimal) {
        let monthlyRate = annualRatePercent / 100.0 / 12.0
        let newBalance = max(0, outstandingPrincipal - prepaymentAmount)

        guard monthlyRate > 0, currentEMI > 0, outstandingPrincipal > 0 else {
            return (0, 0)
        }

        let originalMonths = monthsToPayoff(balance: outstandingPrincipal, monthlyRate: monthlyRate, emi: currentEMI)

        guard newBalance > 0 else {
            // Prepayment clears the loan outright: every remaining EMI is
            // saved, minus the prepayment itself.
            let interestSaved = max(0, (currentEMI * Decimal(originalMonths)) - outstandingPrincipal - (prepaymentAmount - outstandingPrincipal))
            return (0, interestSaved)
        }

        let newMonths = monthsToPayoff(balance: newBalance, monthlyRate: monthlyRate, emi: currentEMI)

        // Interest without prepayment vs. with it: the money spent paying
        // down `prepaymentAmount` early is not itself interest, so it's
        // subtracted back out.
        let interestWithoutPrepayment = (currentEMI * Decimal(originalMonths)) - outstandingPrincipal
        let interestWithPrepayment = (currentEMI * Decimal(newMonths)) - newBalance
        let interestSaved = max(0, interestWithoutPrepayment - interestWithPrepayment)

        return (newMonths, interestSaved)
    }

    /// Months to zero out `balance` at a fixed EMI and monthly rate:
    /// n = -log(1 - r·P/EMI) / log(1+r).
    private static func monthsToPayoff(balance: Decimal, monthlyRate: Double, emi: Decimal) -> Int {
        let emiDouble = NSDecimalNumber(decimal: emi).doubleValue
        let balanceDouble = NSDecimalNumber(decimal: balance).doubleValue
        let ratio = 1 - (monthlyRate * balanceDouble / emiDouble)
        guard ratio > 0 else { return 0 }
        return Int(ceil(-log(ratio) / log(1 + monthlyRate)))
    }
}

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}
