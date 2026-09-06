import Foundation
import SwiftData
import SwiftUI

/// A spending category, used both to tag `Transaction`s (via
/// `Transaction.categoryRef`) and as the unit a `Budget` is set against.
///
/// Pre-seeded with a sensible default set on first run (see
/// `PersistenceController.seedDefaultCategoriesIfNeeded`), and the user can
/// add their own alongside those.
///
/// Every property has a default value and there are no `.unique` constraints,
/// matching the rest of the schema's CloudKit-eligibility requirements.
@Model
nonisolated final class ExpenseCategory {

    // MARK: - Stored Properties

    var id: String = UUID().uuidString

    var name: String = ""

    var systemImage: String = "tag.fill"

    /// Stored as a hex string (e.g. "FF6B6B") rather than `Color` directly,
    /// since `Color` isn't natively Codable/CloudKit-storable.
    var colorHex: String = "6C5CE7"

    /// Built-in categories can be hidden but not deleted, so a stray budget
    /// or historical transaction never ends up pointing at nothing.
    var isBuiltIn: Bool = false

    var isHidden: Bool = false

    var sortOrder: Int = 0

    var createdDate: Date = Date()

    @Relationship(
        deleteRule: .nullify,
        inverse: \Transaction.categoryRef
    )
    var transactions: [Transaction]? = []

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        name: String,
        systemImage: String,
        colorHex: String,
        isBuiltIn: Bool = false,
        isHidden: Bool = false,
        sortOrder: Int = 0,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.systemImage = systemImage
        self.colorHex = colorHex
        self.isBuiltIn = isBuiltIn
        self.isHidden = isHidden
        self.sortOrder = sortOrder
        self.createdDate = createdDate
    }

    // MARK: - UI Helpers

    /// Converts the stored hex string into a SwiftUI Color.
    ///
    /// This property is Main Actor isolated because SwiftUI `Color` APIs
    /// are Main Actor isolated under Swift 6 concurrency checking.
    @MainActor
    var color: Color {
        Color(hex: colorHex) ?? Color.bankPrimary
    }
}


// MARK: - Default Categories

extension ExpenseCategory {

    /// The starter set seeded on first run.
    ///
    /// Matches Windfall's "pre-seeded + custom categories" requirement.
    /// Names/icons are chosen to read clearly as expense buckets rather
    /// than banking-product categories.
    static let defaultSeedSet: [
        (
            name: String,
            systemImage: String,
            colorHex: String
        )
    ] = [

        (
            "Groceries",
            "cart.fill",
            "34C759"
        ),

        (
            "Dining",
            "fork.knife",
            "FF9500"
        ),

        (
            "Transport",
            "car.fill",
            "5AC8FA"
        ),

        (
            "Fuel",
            "fuelpump.fill",
            "FF3B30"
        ),

        (
            "Shopping",
            "bag.fill",
            "AF52DE"
        ),

        (
            "Entertainment",
            "popcorn.fill",
            "FF2D55"
        ),

        (
            "Bills & Utilities",
            "bolt.fill",
            "FFCC00"
        ),

        (
            "Health",
            "cross.case.fill",
            "30D158"
        ),

        (
            "Rent & Housing",
            "house.fill",
            "007AFF"
        ),

        (
            "Subscriptions",
            "repeat.circle.fill",
            "5856D6"
        ),

        (
            "Travel",
            "airplane",
            "64D2FF"
        ),

        (
            "Income",
            "arrow.down.circle.fill",
            "32D74B"
        ),

        (
            "Other",
            "ellipsis.circle.fill",
            "8E8E93"
        )
    ]

    /// Used by the NL/OCR pipeline and quick-add defaults to fall back
    /// to something sensible when nothing more specific is inferred.
    static let otherCategoryName = "Other"

    static let incomeCategoryName = "Income"
}


// MARK: - SwiftUI Color Hex Support

extension Color {

    /// Creates a SwiftUI Color from a six-character RGB hex string.
    ///
    /// Examples:
    /// - "FF0000"
    /// - "#FF0000"
    /// - "6C5CE7"
    ///
    /// Main Actor isolation is required because SwiftUI Color construction
    /// is Main Actor isolated under Swift 6 concurrency checking.
    @MainActor
    init?(hex: String) {

        var sanitized = hex
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        sanitized = sanitized.replacingOccurrences(
            of: "#",
            with: ""
        )

        guard
            sanitized.count == 6,
            let value = UInt64(
                sanitized,
                radix: 16
            )
        else {
            return nil
        }

        let red = Double(
            (value >> 16) & 0xFF
        ) / 255

        let green = Double(
            (value >> 8) & 0xFF
        ) / 255

        let blue = Double(
            value & 0xFF
        ) / 255

        self = Color(
            red: red,
            green: green,
            blue: blue
        )
    }
}
