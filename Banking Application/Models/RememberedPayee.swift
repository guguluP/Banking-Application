import Foundation
import SwiftData

/// The user's label for a person they paid directly. Keyed by VPA or name, so
/// the next debit to that same payee can reuse "Spent through Uber" or Groceries.
/// A different person is not covered by this row.
@Model
nonisolated final class RememberedPayee {
    var id: String = UUID().uuidString
    var payeeKey: String = ""
    var label: String = ""
    var personName: String = ""
    var categoryName: String = ""
    var displayTitle: String = ""

    init(payeeKey: String, label: String, personName: String, categoryName: String, displayTitle: String) {
        self.payeeKey = payeeKey
        self.label = label
        self.personName = personName
        self.categoryName = categoryName
        self.displayTitle = displayTitle
    }
}
