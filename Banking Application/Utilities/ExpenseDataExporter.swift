import Foundation

/// Turns expense-tracker transactions into a CSV file the user fully owns —
/// no server round trip, written straight to a local file the share sheet
/// can hand off anywhere the user chooses.
enum ExpenseDataExporter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func csv(for entries: [Transaction]) -> String {
        var rows = ["Date,Merchant,Description,Category,Amount,Type,Source,Notes"]

        for entry in entries.sorted(by: { $0.transactionDate > $1.transactionDate }) {
            let date = dateFormatter.string(from: entry.transactionDate)
            let merchant = csvField(entry.merchant ?? "")
            let description = csvField(entry.transactionDescription)
            let category = csvField(entry.categoryRef?.name ?? entry.category ?? "")
            let amount = NSDecimalNumber(decimal: entry.amount).stringValue
            let type = entry.isCredit ? "Income" : "Expense"
            let source = csvField(entry.entrySource.rawValue)
            let notes = csvField(entry.notes ?? "")
            rows.append([date, merchant, description, category, amount, type, source, notes].joined(separator: ","))
        }

        return rows.joined(separator: "\n")
    }

    /// Quotes a field if it contains a comma, quote, or newline, and
    /// escapes any embedded quotes — standard CSV field encoding.
    private static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    /// Writes the CSV to a temporary file suitable for `ShareLink`/
    /// `UIActivityViewController`, returning the file URL.
    static func writeToTemporaryFile(csv: String, filename: String = "windfall_export") throws -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename)_\(timestamp).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
