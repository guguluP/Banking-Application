import Foundation
import SwiftData

/// A monthly spending limit for one category.
///
/// Progress against the limit is computed on demand from `Transaction` data
/// (via `BudgetViewModel`) rather than stored here, so it is never stale.
///
/// One `Budget` row exists per (category, month).
/// `periodStart` is always normalized to the first instant of its month.
///
/// SwiftData/CloudKit models cannot declare `.unique` constraints, so
/// normalization is used to ensure a category does not silently get two
/// budgets in the same month.
@Model
nonisolated final class Budget {

    var id: String = UUID().uuidString
    var categoryId: String = ""

    /// First day of the budgeted month, time-normalized to midnight.
    var periodStart: Date = Date()

    var limitAmount: Decimal = 0
    var createdDate: Date = Date()

    init(
        id: String = UUID().uuidString,
        categoryId: String,
        periodStart: Date,
        limitAmount: Decimal,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.categoryId = categoryId
        self.periodStart = Self.startOfMonth(periodStart)
        self.limitAmount = limitAmount
        self.createdDate = createdDate
    }

    /// Returns the first instant of the month containing the given date.
    ///
    /// Marked `nonisolated` because `Budget` itself is a nonisolated
    /// SwiftData model and this helper does not require actor isolation.
    private static nonisolated func startOfMonth(_ date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)

        // Use the user's current time zone so the month corresponds
        // to the local calendar rather than UTC.
        calendar.timeZone = .current

        let components = calendar.dateComponents(
            [.year, .month],
            from: date
        )

        return calendar.date(from: components) ?? date
    }
}


/// Represents the current status of a budget based on spending.
enum BudgetStatus {

    case onTrack
    case approaching
    case over

    var label: String {
        switch self {
        case .onTrack:
            return "On track"

        case .approaching:
            return "Approaching limit"

        case .over:
            return "Over budget"
        }
    }
}
