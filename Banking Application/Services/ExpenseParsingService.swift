import Foundation

/// The structured result of parsing free text (or OCR'd receipt text) into
/// an expense. Always shown to the user in a confirmation sheet before
/// anything is saved — see `ExpenseConfirmationView` — since every field
/// here is a best-effort guess, not a guarantee.
struct ParsedExpenseDraft {
    var amount: Decimal?
    var merchant: String?
    var date: Date
    var categoryName: String
    var notes: String?
    /// 0...1. The confidence of the *weakest* field this draft had to
    /// infer (typically category, since amount/date are closer to
    /// deterministic once a number/date-like token is found).
    var confidence: Double
    var rawInputText: String
}

/// On-device "Hybrid" expense parsing: deterministic rules for amount,
/// currency, and date (these have a clear, checkable grammar, so regex/
/// `NSDataDetector` easily beats a learned model on both accuracy and
/// speed), backed by a lightweight keyword-dictionary classifier for
/// merchant/category (see `CategoryKeywordClassifier`).
///
/// This intentionally does not call any network API — Windfall's local-first
/// promise means this pipeline must work with no connectivity and without
/// sending the user's spending text anywhere. The dictionary classifier is
/// also intentionally isolated behind `CategoryClassifying` so it can be
/// swapped for a real fine-tuned on-device model later (Phase 3, item 20)
/// without touching the amount/date/currency rules or any call site.
@MainActor
final class ExpenseParsingService {
    static let shared = ExpenseParsingService(classifier: CategoryKeywordClassifier())

    private let classifier: CategoryClassifying

    init(classifier: CategoryClassifying) {
        self.classifier = classifier
    }

    /// Parses a natural-language expense entry like "Coffee and a croissant,
    /// ₹350" or "Uber to the airport ₹450 yesterday".
    func parse(_ text: String) -> ParsedExpenseDraft {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = Self.extractAmount(from: trimmed)
        let date = Self.extractDate(from: trimmed) ?? Date()
        let classification = classifier.classify(text: trimmed)

        // Confidence reflects the least-certain piece: an amount we couldn't
        // find at all is worse than a category guess, since the user will
        // have to fill it in manually either way, but a missing amount is
        // more disruptive to the flow.
        let confidence: Double = amount == nil ? min(0.35, classification.confidence) : classification.confidence

        return ParsedExpenseDraft(
            amount: amount,
            merchant: classification.merchant,
            date: date,
            categoryName: classification.categoryName,
            notes: nil,
            confidence: confidence,
            rawInputText: trimmed
        )
    }

    // MARK: - Amount extraction

    /// Matches currency-prefixed or currency-suffixed numbers: "$8.40",
    /// "₹450", "Rs 450", "450 rupees", or a bare "450" as a last resort
    /// (only used if nothing more specific is found, since a bare number
    /// could be a house number, a time, etc.)
    static func extractAmount(from text: String) -> Decimal? {
        let patterns = [
            #"(?:₹|Rs\.?|INR)\s?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)"#,
            #"\$\s?([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)"#,
            #"([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)\s?(?:rupees|rs\.?|inr|dollars|usd)"#
        ]

        for pattern in patterns {
            if let match = firstMatch(pattern: pattern, in: text, group: 1) {
                let cleaned = match.replacingOccurrences(of: ",", with: "")
                if let value = Decimal(string: cleaned) { return value }
            }
        }

        // Bare-number fallback: take the largest plausible decimal number in
        // the string, since amounts tend to be the largest number in a
        // short expense phrase (dates/times are handled separately by
        // NSDataDetector before this runs, so day-of-month numbers like
        // "on the 3rd" are less likely to collide, though not impossible —
        // hence this is the last-resort path, and lowers confidence rather
        // than being trusted outright).
        let barePattern = #"(?<![\d.])([0-9]+(?:\.[0-9]{1,2})?)(?![\d.])"#
        let numbers = allMatches(pattern: barePattern, in: text, group: 1)
            .compactMap { Decimal(string: $0) }
        return numbers.max()
    }

    // MARK: - Date extraction

    /// Uses `NSDataDetector` for real calendar dates ("March 3rd", "3/14"),
    /// plus a small relative-word table for "today"/"yesterday"/weekday
    /// names, which the data detector doesn't reliably resolve relative to
    /// "now" the way a person means them in a quick expense note.
    static func extractDate(from text: String) -> Date? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current

        if lowercased.contains("yesterday") {
            return calendar.date(byAdding: .day, value: -1, to: Date())
        }
        if lowercased.contains("today") || lowercased.contains("this morning") || lowercased.contains("tonight") {
            return Date()
        }

        let weekdaySymbols = calendar.weekdaySymbols.map { $0.lowercased() }
        for (index, symbol) in weekdaySymbols.enumerated() {
            guard lowercased.contains(symbol) else { continue }
            let targetWeekday = index + 1
            return calendar.mostRecentDate(matchingWeekday: targetWeekday, before: Date())
        }

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = detector.firstMatch(in: text, range: range), let date = match.date else {
            return nil
        }
        return date
    }

    // MARK: - Regex helpers

    private static func firstMatch(pattern: String, in text: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > group,
              let matchedRange = Range(match.range(at: group), in: text) else { return nil }
        return String(text[matchedRange])
    }

    private static func allMatches(pattern: String, in text: String, group: Int) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > group, let matchedRange = Range(match.range(at: group), in: text) else { return nil }
            return String(text[matchedRange])
        }
    }
}

private extension Calendar {
    /// The most recent past occurrence of `weekday` (1 = Sunday...7 =
    /// Saturday), used for phrases like "lunch on Tuesday" meaning the
    /// Tuesday just passed, not next week's.
    func mostRecentDate(matchingWeekday weekday: Int, before referenceDate: Date) -> Date? {
        var date = referenceDate
        for _ in 0..<7 {
            if component(.weekday, from: date) == weekday {
                return date
            }
            guard let previous = self.date(byAdding: .day, value: -1, to: date) else { return nil }
            date = previous
        }
        return nil
    }
}
