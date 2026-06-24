import Foundation
import MapKit

enum LocationType: String, Codable {
    case atm = "ATM"
    case branch = "Branch"
    case atmAndBranch = "ATM and Branch"
}

enum ServiceType: String, Codable, CaseIterable {
    case cashDeposit = "Cash Deposit"
    case cashWithdrawal = "Cash Withdrawal"
    case checkDeposit = "Check Deposit"
    case billPayment = "Bill Payment"
    case foreignExchange = "Foreign Exchange"
    case notary = "Notary"
    case safeDepositBox = "Safe Deposit Box"
}

struct BankLocation: Identifiable, Codable {
    let id: String
    let name: String
    let locationType: LocationType
    let address: Address
    let phoneNumber: String
    let services: [ServiceType]
    let latitude: Double
    let longitude: Double
    let hours: [String: String] // Day of week to hours mapping
    let isOpenNow: Bool
    let distance: Double? // In meters, calculated when needed
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var formattedHours: String {
        // Simplified - in a real app this would be more sophisticated
        // Format as "Day: Hours" per line. Sort by a conventional weekday order when possible.
        let weekdayOrder = [
            "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
            "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"
        ]
        let orderIndex: [String: Int] = Dictionary(uniqueKeysWithValues: weekdayOrder.enumerated().map { ($1, $0) })
        let lines = hours
            .sorted { (lhs, rhs) in
                let li = orderIndex[lhs.key] ?? Int.max
                let ri = orderIndex[rhs.key] ?? Int.max
                if li != ri { return li < ri }
                return lhs.key < rhs.key
            }
            .map { "\($0.key): \($0.value)" }
        return lines.joined(separator: "\n")
    }
}
