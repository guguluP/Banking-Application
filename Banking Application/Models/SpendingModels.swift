import SwiftUI

struct SpendingDataPoint: Identifiable, Equatable {
    let id = UUID()
    let day: String
    let amount: Decimal
}

struct CategorySpending: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let amount: Decimal
    let color: Color
    
    var formattedAmount: String {
        CurrencyFormatter.shared.string(from: amount)
    }
}