import Foundation

struct NamedSpend: Identifiable {
    var id: String { name }
    var name: String
    var amount: Decimal
    var percentOfTotal: Double
}

struct CategoryTotal: Identifiable {

    var id: String {
        category.id
    }

    let category: ExpenseCategory
    let amount: Decimal
    let percentOfTotal: Double
}

/// Derives all Track-tab analytics from `ExpenseTrackerViewModel`'s
/// `expenseEntries`.
///
/// No separate data store is used because this view model only performs
/// aggregation over transactions that already exist.
@MainActor
@Observable
final class ExpenseAnalyticsViewModel {

    // MARK: - Published Properties

    private(set) var currentMonthTotal: Decimal = 0

    private(set) var previousMonthTotal: Decimal = 0

    private(set) var percentChange: Double?

    private(set) var topCategories: [CategoryTotal] = []
    private(set) var categorySlices: [NamedSpend] = []
    private(set) var dailySpend: [NamedSpend] = []
    private(set) var merchants: [NamedSpend] = []
    private(set) var accounts: [NamedSpend] = []

    // MARK: - Initialization

    init(tracker: ExpenseTrackerViewModel) {
        recompute(entries: tracker.filteredEntries(searchText: ""))
        observe(tracker)
    }

    private func observe(_ tracker: ExpenseTrackerViewModel) {
        withObservationTracking {
            _ = tracker.expenseEntries
        } onChange: { [weak self, weak tracker] in
            Task { @MainActor [weak self, weak tracker] in
                guard let self, let tracker else { return }
                await Task.yield()
                self.recompute(entries: tracker.filteredEntries(searchText: ""))
                self.observe(tracker)
            }
        }
    }

    // MARK: - Recompute Analytics

    func recompute(entries: [Transaction]) {

        let calendar = Calendar.current
        let now = Date()

        // Find the first instant of the current month.
        let currentStart = Self.startOfMonth(
            now,
            calendar: calendar
        )

        // Find the first instant of next month and previous month.
        guard
            let nextMonthStart = calendar.date(
                byAdding: .month,
                value: 1,
                to: currentStart
            ),
            let previousStart = calendar.date(
                byAdding: .month,
                value: -1,
                to: currentStart
            )
        else {
            return
        }

        // MARK: Current Month

        let currentMonthEntries = entries.filter { entry in

            entry.isDebit &&
            entry.transactionDate >= currentStart &&
            entry.transactionDate < nextMonthStart
        }

        // MARK: Previous Month

        let previousMonthEntries = entries.filter { entry in

            entry.isDebit &&
            entry.transactionDate >= previousStart &&
            entry.transactionDate < currentStart
        }

        // MARK: Totals

        currentMonthTotal = currentMonthEntries.reduce(
            Decimal(0)
        ) { total, transaction in

            total + transaction.amount
        }

        previousMonthTotal = previousMonthEntries.reduce(
            Decimal(0)
        ) { total, transaction in

            total + transaction.amount
        }

        // MARK: Percentage Change

        if previousMonthTotal > 0 {

            let change =
                (currentMonthTotal - previousMonthTotal)
                / previousMonthTotal

            percentChange =
                NSDecimalNumber(
                    decimal: change
                ).doubleValue * 100

        } else {

            // There is no meaningful percentage change if
            // there was no spending in the previous month.
            percentChange = nil
        }

        // MARK: Category Breakdown

        topCategories = Self.categoryTotals(
            from: currentMonthEntries,
            grandTotal: currentMonthTotal
        )
        categorySlices = Self.namedTotals(currentMonthEntries, total: currentMonthTotal) { entry in
            entry.categoryRef?.name ?? entry.category ?? "Uncategorized"
        }
        merchants = Self.namedTotals(currentMonthEntries, total: currentMonthTotal) { entry in
            let name = entry.merchant ?? entry.counterparty ?? entry.description
            return name.isEmpty ? "Unknown" : name
        }
        accounts = Self.namedTotals(currentMonthEntries, total: currentMonthTotal) { entry in
            entry.account?.expenseAccountLabel ?? "Account"
        }
        let byDay = Dictionary(grouping: currentMonthEntries) { calendar.startOfDay(for: $0.transactionDate) }
        dailySpend = byDay.keys.sorted().map { day in
            let amount = byDay[day]?.reduce(Decimal(0)) { $0 + $1.amount } ?? 0
            return NamedSpend(name: day.formatted(.dateTime.day().month(.abbreviated)), amount: amount, percentOfTotal: 0)
        }
    }

    // MARK: - Month Helpers

    /// Returns the first instant of the month containing `date`.
    private static nonisolated func startOfMonth(
        _ date: Date,
        calendar: Calendar
    ) -> Date {

        let components = calendar.dateComponents(
            [.year, .month],
            from: date
        )

        return calendar.date(
            from: components
        ) ?? date
    }

    // MARK: - Category Analytics

    private static func namedTotals(
        _ entries: [Transaction],
        total: Decimal,
        name: (Transaction) -> String
    ) -> [NamedSpend] {
        var sums: [String: Decimal] = [:]
        for entry in entries {
            let key = name(entry)
            sums[key, default: 0] += entry.amount
        }
        return sums.map { key, amount in
            let percent = total > 0 ? NSDecimalNumber(decimal: amount / total).doubleValue * 100 : 0
            return NamedSpend(name: key, amount: amount, percentOfTotal: percent)
        }
        .sorted { $0.amount > $1.amount }
    }

    private static func categoryTotals(
        from entries: [Transaction],
        grandTotal: Decimal
    ) -> [CategoryTotal] {

        var totalsByCategory:
            [String: (
                category: ExpenseCategory,
                amount: Decimal
            )] = [:]

        for entry in entries {

            guard let category = entry.categoryRef else {
                continue
            }

            let existingAmount =
                totalsByCategory[category.id]?.amount ?? 0

            totalsByCategory[category.id] = (
                category: category,
                amount: existingAmount + entry.amount
            )
        }

        return totalsByCategory.values
            .map { pair in

                let percent: Double

                if grandTotal > 0 {

                    percent =
                        NSDecimalNumber(
                            decimal: pair.amount / grandTotal
                        ).doubleValue * 100

                } else {

                    percent = 0
                }

                return CategoryTotal(
                    category: pair.category,
                    amount: pair.amount,
                    percentOfTotal: percent
                )
            }
            .sorted { first, second in

                first.amount > second.amount
            }
    }
}
