import Foundation
import PDFKit
#if canImport(UIKit)
import UIKit
#endif

enum StatementExporter {
    static func csv(for transactions: [Transaction], accountLabel: String) -> String {
        var rows = ["Account,Date,Description,Merchant,Category,Amount,Type,Reference,Location"]
        for tx in transactions.sorted(by: { $0.transactionDate > $1.transactionDate }) {
            let date = ISO8601DateFormatter().string(from: tx.transactionDate)
            let amt = NSDecimalNumber(decimal: tx.amount).stringValue
            rows.append([
                csv(accountLabel),
                csv(date),
                csv(tx.description),
                csv(tx.merchant ?? ""),
                csv(tx.category ?? ""),
                amt,
                tx.isCredit ? "Credit" : "Debit",
                csv(tx.referenceNumber ?? ""),
                csv(tx.location ?? "")
            ].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    static func taxSummary(fds: [FixedDeposit], year: Int) -> String {
        let cal = Calendar.current
        let earned = fds.filter {
            cal.component(.year, from: $0.startDate) <= year && $0.status != .closed
        }
        var lines = ["Form 16A-style interest certificate (illustrative)", "Year: \(year)"]
        var total: Decimal = 0
        for fd in earned {
            let interest = fd.maturityValue - fd.principal
            total += max(0, interest)
            lines.append("\(fd.nickname): interest \(CurrencyFormatter.shared.string(from: max(0, interest)))")
        }
        lines.append("Total interest: \(CurrencyFormatter.shared.string(from: total))")
        lines.append("TDS (illustrative 10%): \(CurrencyFormatter.shared.string(from: total * Decimal(0.10)))")
        return lines.joined(separator: "\n")
    }

    static func receiptText(_ transactions: [Transaction], query: String) -> String {
        let q = query.lowercased()
        let hits = transactions.filter {
            ($0.notes ?? "").localizedCaseInsensitiveContains(q)
            || ($0.merchant ?? "").localizedCaseInsensitiveContains(q)
            || $0.description.localizedCaseInsensitiveContains(q)
        }
        if hits.isEmpty { return "No receipt line items matched that store." }
        return hits.prefix(8).map {
            let items = $0.notes ?? $0.description
            return "\($0.merchant ?? $0.description): \(items) — \(CurrencyFormatter.shared.string(from: $0.amount))"
        }.joined(separator: "\n")
    }

    static func passwordProtectedPDF(for transactions: [Transaction], accountLabel: String, password: String) -> Data? {
        #if canImport(UIKit)
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let raw = renderer.pdfData { ctx in
            ctx.beginPage()
            let body = csv(for: transactions, accountLabel: accountLabel)
            body.draw(in: page.insetBy(dx: 36, dy: 36), withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)])
        }
        guard let document = PDFDocument(data: raw) else { return nil }
        return document.dataRepresentation(options: [
            PDFDocumentWriteOption.userPasswordOption: password,
            PDFDocumentWriteOption.ownerPasswordOption: password
        ])
        #else
        return nil
        #endif
    }

    private static func csv(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
