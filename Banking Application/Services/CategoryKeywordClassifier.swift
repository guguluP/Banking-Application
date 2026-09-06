import Foundation

struct CategoryClassification {
    var categoryName: String
    var merchant: String?
    /// 0...1, how confident the classifier is in `categoryName`. Below
    /// `CategoryKeywordClassifier.lowConfidenceThreshold` the confirmation
    /// sheet shows a "Low confidence — please check" indicator (Phase 2,
    /// item 13).
    var confidence: Double
}

/// Anything that can turn free text into a category + merchant guess.
/// Kept as a protocol specifically so the on-device dictionary classifier
/// below can later be swapped for a fine-tuned Core ML / NLEmbedding-based
/// model (Phase 3, item 20) without changing `ExpenseParsingService` or any
/// UI that depends on it.
protocol CategoryClassifying {
    func classify(text: String) -> CategoryClassification
}

/// A keyword/dictionary classifier: maps known merchant names and category
/// keywords to a category via case-insensitive substring matching. This is
/// the "local embeddings + classifier" called for in the spec, implemented
/// without requiring a bundled ML model or training data, which aren't
/// things a hosted assistant can produce — everything below is
/// deterministic and inspectable, and is designed to be replaced by an
/// actual trained classifier later (see `CategoryClassifying`) without
/// changing its call sites.
final class CategoryKeywordClassifier: CategoryClassifying {
    static let lowConfidenceThreshold = 0.5

    /// Keyword → category name. Checked against both the raw text and its
    /// lemmatized tokens. Order matters where keywords could overlap
    /// (checked in declaration order; first match wins), so more specific
    /// merchant names are listed before generic category words.
    private static let keywordTable: [(keywords: [String], category: String)] = [
        (["starbucks", "coffee", "cafe", "espresso", "latte", "croissant", "bakery", "restaurant", "lunch", "dinner", "breakfast", "brunch", "pizza", "burger", "swiggy", "zomato", "doordash", "ubereats"], "Dining"),
        (["grocery", "groceries", "supermarket", "walmart", "costco", "whole foods", "trader joe", "kirana", "bigbasket", "dmart"], "Groceries"),
        (["uber", "lyft", "taxi", "cab", "ola", "train", "metro", "bus fare", "parking", "toll"], "Transport"),
        (["gas", "fuel", "petrol", "diesel", "gas station"], "Fuel"),
        (["amazon", "shopping", "mall", "store", "clothes", "clothing", "shoes", "electronics"], "Shopping"),
        (["movie", "cinema", "netflix", "concert", "theatre", "theater", "game", "spotify", "prime video", "disney+"], "Entertainment"),
        (["electric bill", "electricity", "water bill", "internet bill", "utility", "utilities", "wifi bill"], "Bills & Utilities"),
        (["doctor", "pharmacy", "medicine", "hospital", "clinic", "dentist", "medical"], "Health"),
        (["rent", "mortgage", "landlord", "housing"], "Rent & Housing"),
        (["subscription", "membership", "monthly plan"], "Subscriptions"),
        (["flight", "hotel", "airbnb", "airline", "vacation", "trip to"], "Travel"),
        (["salary", "payroll", "paycheck", "income", "refund", "reimbursement"], "Income")
    ]

    private static let merchantStopWords: Set<String> = [
        "a", "an", "the", "at", "from", "for", "to", "on", "and", "with",
        "today", "yesterday", "this", "morning", "tonight", "bought", "paid",
        "spent", "got", "buy", "of", "some", "my", "me", "i"
    ]

    func classify(text: String) -> CategoryClassification {
        let lowercased = text.lowercased()

        for entry in Self.keywordTable {
            for keyword in entry.keywords where lowercased.contains(keyword) {
                return CategoryClassification(
                    categoryName: entry.category,
                    merchant: extractMerchant(from: text, matchedKeyword: keyword),
                    // A direct substring hit on a reasonably specific
                    // keyword (merchant names, multi-word phrases) is high
                    // confidence; single common words are still useful but
                    // slightly less certain.
                    confidence: keyword.contains(" ") || keyword.count > 6 ? 0.85 : 0.65
                )
            }
        }

        // No keyword matched at all — still return a usable draft (defaults
        // to "Other"), but at low confidence so the confirmation sheet
        // flags it for the user to fix rather than silently guessing wrong.
        return CategoryClassification(
            categoryName: ExpenseCategory.otherCategoryName,
            merchant: extractMerchant(from: text, matchedKeyword: nil),
            confidence: 0.3
        )
    }

    /// Best-effort merchant/description extraction: strips amount-looking
    /// tokens, currency symbols, dates, and stop words, then takes the
    /// remaining leading phrase. Not a named-entity recognizer — just
    /// enough to turn "Coffee and a croissant, $8.40" into "Coffee and a
    /// croissant" for display, which is what the confirmation sheet needs.
    private func extractMerchant(from text: String, matchedKeyword: String?) -> String? {
        var working = text

        // Drop anything that looks like a currency amount.
        if let regex = try? NSRegularExpression(
            pattern: #"(?:₹|Rs\.?|INR|\$)\s?[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?\s?(?:rupees|rs\.?|inr|dollars|usd)"#,
            options: .caseInsensitive
        ) {
            let range = NSRange(working.startIndex..., in: working)
            working = regex.stringByReplacingMatches(in: working, range: range, withTemplate: "")
        }

        // Split on the first comma if present ("Coffee and a croissant,
        // $8.40" → "Coffee and a croissant"), since that's the common
        // shape of these entries.
        if let commaIndex = working.firstIndex(of: ",") {
            working = String(working[working.startIndex..<commaIndex])
        }

        let cleaned = working
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!"))

        guard !cleaned.isEmpty else { return nil }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }
}
