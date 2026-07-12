import Foundation
import SwiftData

@Model
nonisolated final class UPITransaction {
    var id: String = UUID().uuidString
    var upiId: String = ""
    var amount: Decimal = 0
    var date: Date = Date()

    init(id: String = UUID().uuidString, upiId: String, amount: Decimal, date: Date = Date()) {
        self.id = id
        self.upiId = upiId
        self.amount = amount
        self.date = date
    }
}
