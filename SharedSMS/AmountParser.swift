import Foundation

/// One parser for every typed or scraped rupee amount.
///
/// Accepts everything `Decimal(string:)` accepted before, plus a leading or trailing
/// currency marker (`₹`, `Rs`, `Rs.`, `INR`), surrounding whitespace and digit-grouping
/// commas (`1,00,000` or `100,000`). Anything else is handed to `Decimal(string:)`
/// unchanged, so the result for an input that already parsed is the same as before.
nonisolated enum AmountParser {
    private static let currencyMarkers = ["₹", "rs.", "rs", "inr"]

    static func parse(_ raw: String) -> Decimal? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        for marker in currencyMarkers {
            if text.lowercased().hasPrefix(marker) {
                text = String(text.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        for marker in currencyMarkers {
            if text.lowercased().hasSuffix(marker) {
                text = String(text.dropLast(marker.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        text = removingGroupingCommas(from: text)
        guard !text.isEmpty else { return nil }
        return Decimal(string: text)
    }

    /// Drops a comma that follows a digit and precedes a group of two or three digits,
    /// so "1,250.50" and "1,00,000" lose their separators while "1,2" is left alone.
    private static func removingGroupingCommas(from text: String) -> String {
        let characters = Array(text)
        var result = ""
        result.reserveCapacity(characters.count)
        for (index, character) in characters.enumerated() {
            if character == ",", index > 0, characters[index - 1].isASCIIDigit {
                var run = 0
                var next = index + 1
                while next < characters.count, characters[next].isASCIIDigit {
                    run += 1
                    next += 1
                }
                if run == 2 || run == 3 { continue }
            }
            result.append(character)
        }
        return result
    }
}

private extension Character {
    nonisolated var isASCIIDigit: Bool { isASCII && isNumber }
}
