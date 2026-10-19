import Foundation

nonisolated struct MerchantMatch: Equatable {
    var displayName: String
    var categoryName: String
}

/// How a direct-to-person debit should be labeled. The bank text only has the
/// person's name; the user says whether it was an Uber ride, groceries, and so on.
nonisolated enum PayeeChoice: String, CaseIterable, Identifiable {
    case uber = "Spent through Uber"
    case ola = "Spent through Ola"
    case cab = "Other cab"
    case groceries = "Groceries"
    case person = "A person"
    case rent = "Rent"
    case other = "Other"

    var id: String { rawValue }

    var categoryName: String {
        switch self {
        case .uber, .ola, .cab: return "Transport"
        case .groceries: return "Groceries"
        case .rent: return "Rent & Housing"
        case .person, .other: return ExpenseCategory.otherCategoryName
        }
    }

    var label: String {
        switch self {
        case .uber: return "Uber"
        case .ola: return "Ola"
        case .cab: return "Cab"
        case .groceries: return "Groceries"
        case .person: return "Person"
        case .rent: return "Rent"
        case .other: return "Other"
        }
    }

    func title(person: String) -> String {
        let who = person.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .uber: return who.isEmpty ? "Uber" : "Uber · \(who)"
        case .ola: return who.isEmpty ? "Ola" : "Ola · \(who)"
        case .cab: return who.isEmpty ? "Cab" : "Cab · \(who)"
        case .groceries, .person, .rent, .other:
            return who.isEmpty ? categoryName : who
        }
    }
}

/// Company payees (Blinkit, Uber the company) and the check for a person-to-person VPA.
/// Longest alias wins, so Swiggy Instamart is groceries rather than Swiggy dining.
nonisolated enum MerchantDirectory {
    private struct Entry {
        var name: String
        var category: String
        var aliases: [String]
    }

    private static let companies: [Entry] = [
        entry("Swiggy Instamart", "Groceries", "swiggy instamart", "instamart"),
        entry("Blinkit", "Groceries", "blinkit"),
        entry("Zepto", "Groceries", "zepto"),
        entry("BigBasket", "Groceries", "bigbasket", "big basket"),
        entry("JioMart", "Groceries", "jiomart", "jio mart"),
        entry("DMart", "Groceries", "dmart", "d mart"),
        entry("Zomato", "Dining", "zomato"),
        entry("Swiggy", "Dining", "swiggy"),
        entry("Amazon Pay", "Shopping", "amazon pay", "amazonpay"),
        entry("Amazon", "Shopping", "amazon", "amzn"),
        entry("Flipkart", "Shopping", "flipkart"),
        entry("Myntra", "Shopping", "myntra"),
        entry("Ajio", "Shopping", "ajio"),
        entry("Meesho", "Shopping", "meesho"),
        entry("Nykaa", "Shopping", "nykaa"),
        entry("Uber", "Transport", "uber india", "uber"),
        entry("Ola", "Transport", "ola money", "olacabs", "ola"),
        entry("Rapido", "Transport", "rapido")
    ]

    /// Handles used by people, not by a company checkout.
    private static let personHandles: Set<String> = [
        "ybl", "oksbi", "okhdfcbank", "okhdfc", "okaxis", "okicici",
        "paytm", "ibl", "axl", "upi"
    ]

    static func company(in text: String) -> MerchantMatch? {
        let lower = text.lowercased()
        var best: (name: String, category: String, length: Int)?
        for company in companies {
            for alias in company.aliases where contains(alias, in: lower) {
                if best == nil || alias.count > best!.length {
                    best = (company.name, company.category, alias.count)
                }
            }
        }
        return best.map { MerchantMatch(displayName: $0.name, categoryName: $0.category) }
    }

    /// True when the bank named a person or a personal UPI handle, and no company alias matched.
    static func isPersonPayee(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, company(in: trimmed) == nil else { return false }
        if let vpa = firstVPA(in: trimmed) {
            let handle = vpa.split(separator: "@").last.map { String($0).lowercased() } ?? ""
            return personHandles.contains(handle)
        }
        return looksLikeHumanName(trimmed)
    }

    static func payeeKey(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let vpa = firstVPA(in: trimmed) { return vpa.lowercased() }
        return trimmed.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func personName(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let vpa = firstVPA(in: trimmed) {
            let local = vpa.split(separator: "@").first.map(String.init) ?? vpa
            if local.allSatisfy(\.isNumber) { return local }
            return local
                .split { $0 == "." || $0 == "_" || $0 == "-" }
                .map { String($0).capitalized }
                .joined(separator: " ")
        }
        return trimmed.split(whereSeparator: \.isWhitespace).map { String($0).capitalized }.joined(separator: " ")
    }

    private static func entry(_ name: String, _ category: String, _ aliases: String...) -> Entry {
        Entry(name: name, category: category, aliases: aliases)
    }

    private static func contains(_ alias: String, in text: String) -> Bool {
        if alias.contains(" ") { return text.contains(alias) }
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: alias))\\b"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func firstVPA(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"([A-Za-z0-9][A-Za-z0-9.\-_]{1,40}@[A-Za-z][A-Za-z0-9]{1,20})"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let hit = regex.firstMatch(in: text, range: range),
              let slice = Range(hit.range(at: 1), in: text) else { return nil }
        return String(text[slice])
    }

    private static func looksLikeHumanName(_ text: String) -> Bool {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard (1...4).contains(words.count) else { return false }
        return words.allSatisfy { word in
            word.count >= 2 && word.allSatisfy { $0.isLetter || $0 == "'" || $0 == "." }
        }
    }
}
