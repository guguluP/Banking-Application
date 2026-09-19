import Foundation

/// On-device intelligence: health score, briefing, cash-flow, anomalies,
/// recurring payees, and budget-aware answers. No network.
enum FinancialIntelligenceService {

    struct Briefing {
        var headline: String
        var details: [String]
        var healthScore: Int
    }

    struct RecurringCandidate: Identifiable {
        var id: String { "\(payee)-\(NSDecimalNumber(decimal: amount).stringValue)" }
        var payee: String
        var amount: Decimal
        var occurrences: Int
        var lastDate: Date
    }

    struct Anomaly: Identifiable {
        var id: String
        var transactionId: String
        var reason: String
        var amount: Decimal
        var description: String
    }

    struct CashFlowProjection {
        var currentBalance: Decimal
        var projectedBalance30d: Decimal
        var upcomingOutflows: Decimal
        var dailySpendVelocity: Decimal
    }

    static func healthScore(
        savingsRate: Double,
        budgetAdherence: Double,
        emiBurden: Double,
        spendingVolatility: Double
    ) -> Int {
        let savings = min(max(savingsRate, 0), 0.6) / 0.4 * 30
        let budget = min(max(budgetAdherence, 0), 1) * 30
        let emi = (1 - min(max(emiBurden, 0), 0.6) / 0.6) * 25
        let vol = (1 - min(max(spendingVolatility, 0), 1)) * 15
        return Int(min(100, max(0, savings + budget + emi + vol)).rounded())
    }

    static func computeHealth(
        accounts: [Account],
        transactions: [Transaction],
        budgets: [Budget],
        loans: [Loan]
    ) -> Int {
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        let monthTx = transactions.filter { $0.transactionDate >= monthStart }
        let income = monthTx.filter(\.isCredit).reduce(Decimal(0)) { $0 + $1.amount }
        let spend = monthTx.filter(\.isDebit).reduce(Decimal(0)) { $0 + $1.amount }
        let savingsRate: Double
        if income > 0 {
            savingsRate = NSDecimalNumber(decimal: (income - spend) / income).doubleValue
        } else {
            savingsRate = 0.1
        }

        var adherence = 1.0
        if !budgets.isEmpty {
            let spentByCat = Dictionary(grouping: monthTx.filter(\.isDebit), by: { $0.category ?? "Other" })
                .mapValues { $0.reduce(Decimal(0)) { $0 + $1.amount } }
            var ratios: [Double] = []
            for b in budgets where b.limitAmount > 0 {
                let spent = spentByCat[b.categoryId] ?? 0
                let r = NSDecimalNumber(decimal: spent / b.limitAmount).doubleValue
                ratios.append(min(r, 1.5))
            }
            if !ratios.isEmpty {
                let avgOver = ratios.map { max(0, $0 - 1) }.reduce(0, +) / Double(ratios.count)
                adherence = max(0, 1 - avgOver)
            }
        }

        let totalAvail = accounts.filter { $0.accountType != .credit }.reduce(Decimal(0)) { $0 + $1.availableBalance }
        let monthlyEMI = loans.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.emiAmount }
        let emiBurden: Double
        if totalAvail > 0 {
            emiBurden = NSDecimalNumber(decimal: monthlyEMI / max(totalAvail, 1)).doubleValue
        } else {
            emiBurden = monthlyEMI > 0 ? 0.5 : 0
        }

        let dailySpend = Dictionary(grouping: monthTx.filter(\.isDebit)) {
            Calendar.current.startOfDay(for: $0.transactionDate)
        }.mapValues { $0.reduce(Decimal(0)) { $0 + $1.amount } }
        let amounts = dailySpend.values.map { NSDecimalNumber(decimal: $0).doubleValue }
        let mean = amounts.isEmpty ? 0 : amounts.reduce(0, +) / Double(amounts.count)
        let variance = amounts.isEmpty || mean == 0 ? 0 : amounts.map { pow($0 - mean, 2) }.reduce(0, +) / Double(amounts.count)
        let volatility = mean == 0 ? 0 : min(sqrt(variance) / mean, 1)

        return healthScore(
            savingsRate: savingsRate,
            budgetAdherence: adherence,
            emiBurden: emiBurden,
            spendingVolatility: volatility
        )
    }

    static func briefing(
        transactions: [Transaction],
        billers: [Biller],
        loans: [Loan],
        fds: [FixedDeposit],
        categoryBreakdown: [CategorySpending],
        lastMonthSpend: Decimal,
        health: Int
    ) -> Briefing {
        let cal = Calendar.current
        let weekEnd = cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let billsDue = loans.filter { $0.status == .active && $0.nextDueDate <= weekEnd }
        let fdsMaturing = fds.filter { $0.status == .active && $0.maturityDate <= weekEnd }

        let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        let spend = transactions.filter { $0.isDebit && $0.transactionDate >= thisMonthStart }.reduce(Decimal(0)) { $0 + $1.amount }

        var details: [String] = []
        if !billsDue.isEmpty {
            details.append("\(billsDue.count) EMI\(billsDue.count == 1 ? "" : "s") due this week.")
        }
        if !billers.isEmpty {
            details.append("\(billers.count) saved biller\(billers.count == 1 ? "" : "s") ready for pay.")
        }
        if lastMonthSpend > 0 {
            let delta = NSDecimalNumber(decimal: (spend - lastMonthSpend) / lastMonthSpend).doubleValue
            let pct = Int((delta * 100).rounded())
            if abs(pct) >= 5 {
                details.append("Spending is \(abs(pct))% \(pct >= 0 ? "above" : "below") last month.")
            }
        }
        if let top = categoryBreakdown.first {
            details.append("Top category: \(top.name) (\(CurrencyFormatter.shared.string(from: top.amount))).")
        }
        if !fdsMaturing.isEmpty {
            details.append("\(fdsMaturing.count) FD maturing soon.")
        }

        let headline: String
        if details.isEmpty {
            headline = "You're in good shape — health score \(health)."
        } else {
            headline = details[0] + " Financial health: \(health)/100."
        }
        return Briefing(headline: headline, details: Array(details.dropFirst()), healthScore: health)
    }

    static func cashFlow(
        currentBalance: Decimal,
        transactions: [Transaction],
        loans: [Loan],
        billers: [Biller]
    ) -> CashFlowProjection {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let spend = transactions.filter { $0.isDebit && $0.transactionDate >= start }.reduce(Decimal(0)) { $0 + $1.amount }
        let velocity = spend / 30
        let upcomingLoans = loans.filter { $0.status == .active && $0.nextDueDate <= (cal.date(byAdding: .day, value: 30, to: Date()) ?? Date()) }
            .reduce(Decimal(0)) { $0 + $1.emiAmount }
        let projected = currentBalance - (velocity * 30) - upcomingLoans
        return CashFlowProjection(
            currentBalance: currentBalance,
            projectedBalance30d: projected,
            upcomingOutflows: upcomingLoans,
            dailySpendVelocity: velocity
        )
    }

    static func detectRecurring(transactions: [Transaction]) -> [RecurringCandidate] {
        let debits = transactions.filter(\.isDebit)
        let grouped = Dictionary(grouping: debits) { tx -> String in
            let payee = (tx.merchant ?? tx.counterparty ?? tx.description).lowercased()
            let amountKey = NSDecimalNumber(decimal: tx.amount).stringValue
            return "\(payee)|\(amountKey)"
        }
        return grouped.compactMap { key, txs -> RecurringCandidate? in
            guard txs.count >= 2 else { return nil }
            let parts = key.split(separator: "|")
            guard parts.count == 2 else { return nil }
            let last = txs.map(\.transactionDate).max() ?? Date()
            return RecurringCandidate(
                payee: String(parts[0]).capitalized,
                amount: txs[0].amount,
                occurrences: txs.count,
                lastDate: last
            )
        }
        .sorted { $0.occurrences > $1.occurrences }
    }

    static func detectAnomalies(transactions: [Transaction]) -> [Anomaly] {
        let debits = transactions.filter(\.isDebit)
        guard debits.count >= 5 else { return [] }
        let values = debits.map { NSDecimalNumber(decimal: $0.amount).doubleValue }
        let mean = values.reduce(0, +) / Double(values.count)
        let std = sqrt(values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count))
        guard std > 0 else { return [] }

        let hourCounts = Dictionary(grouping: debits) {
            Calendar.current.component(.hour, from: $0.transactionDate)
        }.mapValues(\.count)

        return debits.compactMap { tx -> Anomaly? in
            let z = (NSDecimalNumber(decimal: tx.amount).doubleValue - mean) / std
            var reasons: [String] = []
            if z >= 2.5 {
                reasons.append("amount \(String(format: "%.1f", z))σ above typical spend")
            }
            let hour = Calendar.current.component(.hour, from: tx.transactionDate)
            if hour < 6 || hour > 23, (hourCounts[hour] ?? 0) <= 1 {
                reasons.append("unusual time (\(hour):00)")
            }
            if let loc = tx.location, !loc.isEmpty {
                let sameLoc = debits.filter { $0.location == loc }.count
                if sameLoc == 1 {
                    reasons.append("new location: \(loc)")
                }
            }
            guard !reasons.isEmpty else { return nil }
            return Anomaly(
                id: tx.id,
                transactionId: tx.id,
                reason: reasons.joined(separator: "; "),
                amount: tx.amount,
                description: tx.description
            )
        }
    }

    static func budgetAnswer(budgets: [Budget], transactions: [Transaction]) -> String {
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        let monthDebits = transactions.filter { $0.isDebit && $0.transactionDate >= monthStart }
        guard !budgets.isEmpty else {
            return "You haven't set category budgets yet. Add them in Track > Budgets and I can tell you if you're on track."
        }
        var lines: [String] = []
        for b in budgets {
            let spent = monthDebits.filter { $0.category == b.categoryId || $0.categoryRef?.id == b.categoryId }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let remaining = b.limitAmount - spent
            let status: String
            if remaining < 0 {
                status = "over by \(CurrencyFormatter.shared.string(from: abs(remaining)))"
            } else {
                status = "\(CurrencyFormatter.shared.string(from: remaining)) left"
            }
            lines.append("\(b.categoryId): \(status)")
        }
        return "This month: " + lines.joined(separator: ". ") + "."
    }

    static func parseSearch(_ query: String, transactions: [Transaction]) -> [Transaction] {
        let q = query.lowercased()
        let cal = Calendar.current
        var start: Date?
        var end: Date?
        if q.contains("last month") {
            let comps = cal.dateComponents([.year, .month], from: Date())
            let thisMonth = cal.date(from: comps) ?? Date()
            start = cal.date(byAdding: .month, value: -1, to: thisMonth)
            end = thisMonth
        } else if q.contains("this month") || q.contains("last week") == false && q.contains("month") {
            start = cal.date(from: cal.dateComponents([.year, .month], from: Date()))
            end = Date()
        } else if q.contains("last week") || q.contains("this week") {
            start = cal.date(byAdding: .day, value: -7, to: Date())
            end = Date()
        }

        let keywords: [(String, String)] = [
            ("restaurant", "Dining"), ("dining", "Dining"), ("food", "Dining"),
            ("grocery", "Groceries"), ("grocer", "Groceries"),
            ("fuel", "Fuel"), ("petrol", "Fuel"),
            ("transfer", "Transfer")
        ]
        let category = keywords.first { q.contains($0.0) }?.1

        return transactions.filter { tx in
            if let start, tx.transactionDate < start { return false }
            if let end, tx.transactionDate > end { return false }
            if let category {
                return (tx.category ?? "").localizedCaseInsensitiveContains(category)
                    || tx.description.localizedCaseInsensitiveContains(category)
            }
            let tokens = q.split(separator: " ").map(String.init).filter { $0.count > 2 }
            guard !tokens.isEmpty else { return true }
            let hay = (tx.description + " " + (tx.merchant ?? "") + " " + (tx.category ?? "")).lowercased()
            return tokens.contains { hay.contains($0) }
        }
    }
}
