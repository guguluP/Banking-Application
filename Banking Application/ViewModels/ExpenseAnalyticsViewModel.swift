import Foundation
import Combine

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
final class ExpenseAnalyticsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var currentMonthTotal: Decimal = 0

    @Published private(set) var previousMonthTotal: Decimal = 0

    @Published private(set) var percentChange: Double?

    @Published private(set) var topCategories: [CategoryTotal] = []

    // MARK: - Private Properties

    private var cancellable: AnyCancellable?

    // MARK: - Initialization

    init(tracker: ExpenseTrackerViewModel) {

        // Calculate the initial analytics.
        recompute(
            entries: tracker.filteredEntries(searchText: "")
        )

        // Observe changes from the tracker.
        cancellable = tracker.objectWillChange.sink {
            [weak self, weak tracker] _ in

            // objectWillChange is emitted before the underlying data
            // has necessarily finished updating.
            //
            // Hop onto the Main Actor and the next run-loop turn so
            // that we read the updated transaction data.
            Task { @MainActor [weak self, weak tracker] in

                guard let self, let tracker else {
                    return
                }

                await Task.yield()

                self.recompute(
                    entries: tracker.filteredEntries(searchText: "")
                )
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
