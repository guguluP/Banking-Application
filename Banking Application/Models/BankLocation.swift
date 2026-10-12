import Foundation
import MapKit

enum LocationType: String, Codable {
    case atm = "ATM"
    case branch = "Branch"
    case atmAndBranch = "ATM and Branch"
}

enum BankHoursStatus: Equatable {
    case open
    case closed
    /// The hours string could not be read as open or closed.
    case unspecified(String)
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

    /// Open or closed from today's hours string. Ignores the stored `isOpenNow` flag.
    func hoursStatus(at date: Date = Date(), calendar: Calendar = .current) -> BankHoursStatus {
        let index = calendar.component(.weekday, from: date) - 1
        guard (0..<7).contains(index) else {
            return .unspecified(formattedHours.isEmpty ? "Hours not listed" : formattedHours)
        }
        guard let raw = hoursText(forDayIndex: index) else {
            return .unspecified(formattedHours.isEmpty ? "Hours not listed" : formattedHours)
        }
        return Self.interpret(hours: raw, at: date, calendar: calendar)
    }

    private func hoursText(forDayIndex today: Int) -> String? {
        let shortDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let fullDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        // Calendar weekday is Sunday-first; the range keys above are Monday-first.
        let mondayFirst = (today + 6) % 7

        func index(of token: String) -> Int? {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            if let found = shortDays.firstIndex(of: trimmed) { return found }
            if let found = fullDays.firstIndex(of: trimmed) { return found }
            if let found = shortDays.firstIndex(where: { trimmed.hasPrefix($0) }) { return found }
            if let found = fullDays.firstIndex(where: { trimmed.hasPrefix($0) || $0.hasPrefix(trimmed) }) { return found }
            return nil
        }

        for (key, value) in hours {
            let pieces = key.split(separator: "-").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if pieces.count == 1, let day = index(of: pieces[0]), day == mondayFirst {
                return value
            }
            if pieces.count == 2, let start = index(of: pieces[0]), let end = index(of: pieces[1]) {
                if start <= end, mondayFirst >= start, mondayFirst <= end { return value }
                if start > end, mondayFirst >= start || mondayFirst <= end { return value }
            }
        }
        return nil
    }

    private static func interpret(hours text: String, at date: Date, calendar: Calendar) -> BankHoursStatus {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.caseInsensitiveCompare("Closed") == .orderedSame { return .closed }
        if trimmed.range(of: "24", options: .caseInsensitive) != nil,
           trimmed.range(of: "hour", options: .caseInsensitive) != nil {
            return .open
        }

        let normalized = trimmed
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        let parts = normalized.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2 else { return .unspecified(trimmed) }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = calendar.timeZone
        parser.dateFormat = "h:mm a"
        guard let openDate = parser.date(from: parts[0]), let closeDate = parser.date(from: parts[1]) else {
            return .unspecified(trimmed)
        }

        func minutes(_ source: Date) -> Int {
            let parts = calendar.dateComponents([.hour, .minute], from: source)
            return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
        let now = minutes(date)
        let open = minutes(openDate)
        let close = minutes(closeDate)
        if close >= open {
            return (now >= open && now < close) ? .open : .closed
        }
        return (now >= open || now < close) ? .open : .closed
    }
}
