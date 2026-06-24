import Foundation

struct UPITransaction: Identifiable, Codable, Hashable {
    let id: String
    let upiId: String
    let amount: Decimal
    let date: Date
}