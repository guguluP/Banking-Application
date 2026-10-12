import Foundation
import CryptoKit
import SwiftData

enum ImportDirection: String, Codable {
    case debit
    case credit
}

struct RawBankEvent: Equatable {
    var amount: Decimal
    var direction: ImportDirection
    var accountLast4: String
    var merchant: String?
    var externalRef: String?
    var occurredAt: Date
    var bank: String
    var source: TransactionEntrySource
    var confidence: Double
}

enum ImportEventStatus: String, Codable {
    case pendingReview = "Pending review"
    case posted = "Posted"
    case duplicate = "Duplicate"
    case rejected = "Rejected"
    case ignored = "Ignored"
}

@Model
nonisolated final class ImportedEvent {
    var id: String = UUID().uuidString
    var sourceRaw: String = TransactionEntrySource.smsImport.rawValue
    var statusRaw: String = ImportEventStatus.pendingReview.rawValue
    var amount: Decimal = 0
    var directionRaw: String = ImportDirection.debit.rawValue
    var accountLast4: String = ""
    var merchant: String = ""
    var externalRef: String?
    var rawHash: String = ""
    var bank: String = ""
    var occurredAt: Date = Date()
    var confidence: Double = 0
    var categoryName: String = "Uncategorized"

    var source: TransactionEntrySource {
        get { TransactionEntrySource(rawValue: sourceRaw) ?? .smsImport }
        set { sourceRaw = newValue.rawValue }
    }
    var status: ImportEventStatus {
        get { ImportEventStatus(rawValue: statusRaw) ?? .pendingReview }
        set { statusRaw = newValue.rawValue }
    }

    init(event: RawBankEvent, hash: String, categoryName: String) {
        self.sourceRaw = event.source.rawValue
        self.amount = event.amount
        self.directionRaw = event.direction.rawValue
        self.accountLast4 = event.accountLast4
        self.merchant = event.merchant ?? ""
        self.externalRef = event.externalRef
        self.rawHash = hash
        self.bank = event.bank
        self.occurredAt = event.occurredAt
        self.confidence = event.confidence
        self.categoryName = categoryName
    }
}

@Model
nonisolated final class AAConsent {
    var id: String = UUID().uuidString
    var mobile: String = ""
    var provider: String = "sandbox"
    var status: String = "active"
    var createdAt: Date = Date()

    init(mobile: String, provider: String) {
        self.mobile = mobile
        self.provider = provider
    }
}

enum BankSMSParser {
    static func parse(_ text: String, now: Date = Date()) -> RawBankEvent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if IndianBankSMSGrammar.looksLikeOTP(trimmed) { return nil }

        if let captured = IndianBankSMSGrammar.parse(trimmed, now: now) {
            return RawBankEvent(
                amount: captured.amount,
                direction: captured.isCredit ? .credit : .debit,
                accountLast4: captured.accountLast4,
                merchant: captured.merchant,
                externalRef: captured.externalRef,
                occurredAt: captured.occurredAt,
                bank: captured.bank,
                source: .smsImport,
                confidence: captured.confidence
            )
        }

        let draft = ExpenseParsingService.shared.parse(trimmed)
        guard let amount = draft.amount, amount > 0 else { return nil }
        return RawBankEvent(
            amount: amount,
            direction: trimmed.lowercased().contains("credited") ? .credit : .debit,
            accountLast4: last4(in: trimmed) ?? "",
            merchant: draft.merchant,
            externalRef: utr(in: trimmed),
            occurredAt: draft.date,
            bank: "Unknown",
            source: .smsImport,
            confidence: min(0.45, draft.confidence)
        )
    }

    private static func last4(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"(?:\*\*|XX|xx)(\d{4})"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let hit = regex.firstMatch(in: text, range: range), let r = Range(hit.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    private static func utr(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"(?:UTR|Ref)\s*(\d{6,})"#, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let hit = regex.firstMatch(in: text, range: range), let r = Range(hit.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}

@MainActor
enum BankImportPipeline {
    static let reviewThreshold = 0.7

    @discardableResult
    static func ingest(_ event: RawBankEvent, in context: ModelContext) -> ImportedEvent? {
        let hash = rawHash(for: event)
        if isDuplicate(event, hash: hash, in: context) {
            let row = ImportedEvent(event: event, hash: hash, categoryName: "Duplicate")
            row.status = .duplicate
            context.insert(row)
            try? context.save()
            return row
        }
        let draft = ExpenseParsingService.shared.parse(event.merchant ?? event.bank)
        let category = draft.categoryName
        let row = ImportedEvent(event: event, hash: hash, categoryName: category)
        if event.confidence < reviewThreshold {
            row.status = .pendingReview
            context.insert(row)
            try? context.save()
            return row
        }
        if post(row, in: context) {
            return row
        }
        row.status = .pendingReview
        context.insert(row)
        try? context.save()
        return row
    }

    static func ingestCapturedSMS(in context: ModelContext) {
        for text in SMSInbox.drain() {
            _ = ingestSMS(text, in: context)
        }
    }

    static func ingestSMS(_ text: String, in context: ModelContext) -> ImportedEvent? {
        guard let event = BankSMSParser.parse(text) else { return nil }
        return ingest(event, in: context)
    }

    @discardableResult
    static func approve(_ row: ImportedEvent, in context: ModelContext) -> Bool {
        guard row.status == .pendingReview else { return false }
        return post(row, in: context)
    }

    static func reject(_ row: ImportedEvent, in context: ModelContext) {
        row.status = .rejected
        try? context.save()
    }

    static func deleteAggregatorImports(in context: ModelContext) {
        let source = TransactionEntrySource.aggregator.rawValue
        let events = (try? context.fetch(FetchDescriptor<ImportedEvent>())) ?? []
        for event in events where event.sourceRaw == source { context.delete(event) }
        let txs = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        for tx in txs where tx.entrySourceRaw == source {
            let account = tx.account ?? accounts.first { $0.id == tx.accountId }
            if let account {
                if tx.isCredit {
                    account.balance -= tx.amount
                    account.availableBalance -= tx.amount
                } else {
                    account.balance += tx.amount
                    account.availableBalance += tx.amount
                }
            }
            context.delete(tx)
        }
        try? context.save()
    }

    private static func post(_ row: ImportedEvent, in context: ModelContext) -> Bool {
        let last4 = row.accountLast4.trimmingCharacters(in: .whitespaces)
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        guard !last4.isEmpty, let account = accounts.first(where: { String($0.accountNumber.suffix(4)) == last4 }) else {
            return false
        }
        if row.directionRaw == ImportDirection.credit.rawValue {
            if AuthenticationService.movementBlocked { return false }
            if let ref = row.externalRef, !ref.isEmpty {
                let existing = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
                if existing.contains(where: { $0.externalRef == ref || $0.referenceNumber == ref }) {
                    return false
                }
            }
            account.balance += row.amount
            account.availableBalance += row.amount
            let tx = Transaction(
                accountId: account.id,
                type: .deposit,
                amount: row.amount,
                currency: account.currency,
                description: row.merchant.isEmpty ? "Imported credit" : row.merchant,
                referenceNumber: row.externalRef,
                transactionDate: row.occurredAt,
                category: row.categoryName,
                merchant: row.merchant,
                entrySource: row.source
            )
            tx.externalRef = row.externalRef
            tx.rawHash = row.rawHash
            tx.countsInLedger = true
            tx.railRaw = PaymentRail.imported.rawValue
            tx.categoryRef = category(named: row.categoryName, in: context)
            tx.account = account
            context.insert(tx)
        } else {
            do {
                _ = try TransactionService.post(
                    from: account,
                    amount: row.amount,
                    rail: .imported,
                    counterparty: row.merchant,
                    description: row.merchant.isEmpty ? "Imported payment" : row.merchant,
                    category: row.categoryName,
                    externalRef: row.externalRef ?? row.rawHash,
                    currency: account.currency,
                    entrySource: row.source,
                    merchant: row.merchant,
                    occurredAt: row.occurredAt,
                    requireSession: false,
                    in: context
                )
            } catch {
                return false
            }
        }
        let postedRef = (row.externalRef?.isEmpty == false) ? row.externalRef! : row.rawHash
        let txs = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        if let tx = txs.first(where: { $0.externalRef == postedRef || $0.referenceNumber == postedRef }) {
            tx.rawHash = row.rawHash
            tx.entrySource = row.source
            if tx.categoryRef == nil {
                tx.categoryRef = category(named: row.categoryName, in: context)
            }
        }
        row.status = .posted
        if row.modelContext == nil { context.insert(row) }
        try? context.save()
        return true
    }

    private static func isDuplicate(_ event: RawBankEvent, hash: String, in context: ModelContext) -> Bool {
        let events = (try? context.fetch(FetchDescriptor<ImportedEvent>())) ?? []
        if let ref = event.externalRef, events.contains(where: { $0.externalRef == ref && $0.statusRaw != ImportEventStatus.rejected.rawValue }) {
            return true
        }
        if events.contains(where: { $0.rawHash == hash }) { return true }
        let txs = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        if let ref = event.externalRef, txs.contains(where: { $0.externalRef == ref || $0.referenceNumber == ref }) {
            return true
        }
        return txs.contains { tx in
            tx.amount == event.amount
                && abs(tx.transactionDate.timeIntervalSince(event.occurredAt)) < 180
                && (tx.account.map { String($0.accountNumber.suffix(4)) } == event.accountLast4)
                && fuzzy(tx.merchant ?? tx.description, event.merchant ?? "")
        }
    }

    private static func category(named name: String, in context: ModelContext) -> ExpenseCategory? {
        let categories = (try? context.fetch(FetchDescriptor<ExpenseCategory>())) ?? []
        return categories.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private static func fuzzy(_ lhs: String, _ rhs: String) -> Bool {
        let a = lhs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let b = rhs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a == b || a.contains(b) || b.contains(a)
    }

    static func rawHash(for event: RawBankEvent) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.year, .month, .day], from: event.occurredAt)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let payload = "\(event.bank)|\(event.amount)|\(event.accountLast4)|\(event.externalRef ?? "")|\(event.merchant ?? "")|\(day)|\(event.direction.rawValue)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
