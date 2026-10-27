import Foundation
import PDFKit
#if canImport(UIKit)
import UIKit
#endif

enum StatementExporter {
    /// One formatter for every row; `ISO8601DateFormatter` is expensive to create.
    private static let isoFormatter = ISO8601DateFormatter()

    static func csv(for transactions: [Transaction], accountLabel: String) -> String {
        var rows = ["Account,Date,Description,Merchant,Category,Amount,Type,Reference,Location"]
        for tx in transactions.sorted(by: { $0.transactionDate > $1.transactionDate }) {
            let date = isoFormatter.string(from: tx.transactionDate)
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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        var lines = ["Form 16A-style interest certificate (illustrative)", "Year: \(year)"]
        guard
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
            let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else {
            return lines.joined(separator: "\n")
        }

        var total: Decimal = 0
        let ordered = fds.sorted {
            $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
        }
        for fd in ordered {
            // No break or close date is stored, so the term runs through maturityDate.
            // Interval is [start, maturity): days the deposit is outstanding.
            let termStart = calendar.startOfDay(for: fd.startDate)
            let termEnd = calendar.startOfDay(for: fd.maturityDate)
            let overlapStart = max(termStart, yearStart)
            let overlapEnd = min(termEnd, yearEnd)
            let termDays = calendar.dateComponents([.day], from: termStart, to: termEnd).day ?? 0
            let overlapDays = calendar.dateComponents([.day], from: overlapStart, to: overlapEnd).day ?? 0
            guard termDays > 0, overlapDays > 0 else { continue }
            // A broken deposit returns principal only. Matured and active deposits still use the illustrative maturity interest.
            let fullInterest: Decimal = fd.status == .closed ? 0 : max(0, fd.maturityValue - fd.principal)
            let interest = fullInterest * Decimal(overlapDays) / Decimal(termDays)
            total += interest
            lines.append("\(fd.nickname): interest \(CurrencyFormatter.shared.string(from: interest))")
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
        // Without a password there is nothing to export, so skip rendering entirely.
        guard !password.isEmpty else { return nil }
        #if canImport(UIKit)
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 36
        let headerFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let bodyFont = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .paragraphStyle: paragraph
        ]
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont
        ]
        let textWidth = pageRect.width - margin * 2
        let contentTop = margin + headerFont.lineHeight + 8
        let contentBottom = pageRect.height - margin
        let lines = csv(for: transactions, accountLabel: accountLabel).components(separatedBy: "\n")

        func lineHeight(_ line: String) -> CGFloat {
            let sample = line.isEmpty ? " " : line
            let bounds = (sample as NSString).boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: bodyAttributes,
                context: nil
            )
            return max(ceil(bounds.height), bodyFont.lineHeight)
        }

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let raw = renderer.pdfData { ctx in
            var index = 0
            var pageNumber = 0
            repeat {
                ctx.beginPage()
                pageNumber += 1
                let header = "\(accountLabel) statement  ·  Page \(pageNumber)"
                (header as NSString).draw(at: CGPoint(x: margin, y: margin), withAttributes: headerAttributes)
                var y = contentTop
                var drewOnPage = false
                while index < lines.count {
                    let line = lines[index]
                    let height = lineHeight(line)
                    if drewOnPage && y + height > contentBottom {
                        break
                    }
                    let rect = CGRect(x: margin, y: y, width: textWidth, height: height)
                    ((line.isEmpty ? " " : line) as NSString).draw(
                        with: rect,
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: bodyAttributes,
                        context: nil
                    )
                    y += height
                    index += 1
                    drewOnPage = true
                }
            } while index < lines.count
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
