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

    /// Month-by-month run of `balance` at a fixed `emi`, the way a lender applies a
    /// prepayment that keeps the EMI and shortens the tenure. Each month's interest
    /// is rounded to the paisa like `amortizationSchedule`; the last row pays only
    /// what is left plus that month's interest, so it is usually smaller than `emi`.
    /// Empty when the balance is not positive, the EMI does not cover a month's
    /// interest, or payoff would take more than 600 months.
    static func fixedEMISchedule(balance: Decimal, annualRatePercent: Double, emi: Decimal) -> [ScheduleRow] {
        // EMIs and interest are whole paise; rounding through Decimal keeps the sums exact.
        let emi = emi.rounded(scale: 2)
        guard balance > 0, emi > 0 else { return [] }
        let monthlyRate = max(0, annualRatePercent) / 100.0 / 12.0
        var rows: [ScheduleRow] = []
        var remaining = balance
        while remaining > 0 {
            guard rows.count < 600 else { return [] }
            let interest: Decimal
            if monthlyRate > 0 {
                let remainingDouble = NSDecimalNumber(decimal: remaining).doubleValue
                interest = Decimal(remainingDouble * monthlyRate).rounded(scale: 2)
            } else {
                interest = 0
            }
            let payment: Decimal
            let principalPortion: Decimal
            if remaining + interest <= emi {
                payment = remaining + interest
                principalPortion = remaining
            } else {
                payment = emi
                principalPortion = emi - interest
                guard principalPortion > 0 else { return [] }
            }
            remaining -= principalPortion
            rows.append(ScheduleRow(
                id: rows.count + 1,
                month: rows.count + 1,
                emi: payment,
                principalPortion: principalPortion,
                interestPortion: interest,
                remainingBalance: remaining
            ))
        }
        return rows
    }

    /// Effect of a lump-sum prepayment today against the current outstanding
    /// balance, keeping the EMI fixed and shortening the remaining tenure (the
    /// more common prepayment structure Indian lenders offer, versus
    /// recalculating a lower EMI).
    ///
    /// Interest saved is the interest summed over `fixedEMISchedule` without the
    /// prepayment minus the same sum after it, so the smaller final instalment is
    /// not counted as a full EMI. `monthsSaved` compares the two schedules' lengths.
    /// A prepayment that clears the loan saves all remaining interest.
    static func prepaymentImpact(
        outstandingPrincipal: Decimal,
        annualRatePercent: Double,
        currentEMI: Decimal,
        prepaymentAmount: Decimal
    ) -> (newRemainingMonths: Int, interestSaved: Decimal, monthsSaved: Int) {
        let before = fixedEMISchedule(balance: outstandingPrincipal, annualRatePercent: annualRatePercent, emi: currentEMI)
        guard !before.isEmpty else { return (0, 0, 0) }

        let newBalance = max(0, outstandingPrincipal - max(0, prepaymentAmount))
        let after = fixedEMISchedule(balance: newBalance, annualRatePercent: annualRatePercent, emi: currentEMI)

        let interestBefore = before.reduce(Decimal(0)) { $0 + $1.interestPortion }
        let interestAfter = after.reduce(Decimal(0)) { $0 + $1.interestPortion }
        return (
            newRemainingMonths: after.count,
            interestSaved: max(0, interestBefore - interestAfter),
            monthsSaved: max(0, before.count - after.count)
        )
    }

    /// Months to zero out `balance` at a fixed EMI and monthly rate:
    /// n = -log(1 - r·P/EMI) / log(1+r). `log(1 + r)` is 0 when the rate is 0.
    static func monthsToPayoff(balance: Decimal, monthlyRate: Double, emi: Decimal) -> Int {
        let emiDouble = NSDecimalNumber(decimal: emi).doubleValue
        let balanceDouble = NSDecimalNumber(decimal: balance).doubleValue
        guard emiDouble > 0, balanceDouble > 0 else { return 0 }
        if monthlyRate == 0 {
            return Int(ceil(balanceDouble / emiDouble))
        }
        let ratio = 1 - (monthlyRate * balanceDouble / emiDouble)
        guard ratio > 0 else { return 0 }
        let months = -log(ratio) / log(1 + monthlyRate)
        guard months.isFinite, months > 0, months < Double(Int.max) else { return 0 }
        return Int(ceil(months))
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
