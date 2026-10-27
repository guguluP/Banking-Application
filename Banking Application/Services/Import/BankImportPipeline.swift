import Foundation
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
    #Index<ImportedEvent>([\.externalRef], [\.rawHash], [\.occurredAt])

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
    /// Normalized VPA or name, used to remember a person-payee choice.
    var payeeKey: String = ""
    /// Display name of the person when the bank did not name a company.
    var personName: String = ""
    /// True until the user says what a person-to-person debit was for.
    var needsPayeeChoice: Bool = false

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
    private static let last4Regex = try? NSRegularExpression(pattern: #"(?:\*\*|XX|xx)(\d{4})"#)
    private static let utrRegex = try? NSRegularExpression(pattern: #"(?:UTR|Ref)\s*(\d{6,})"#, options: [.caseInsensitive])

    static func parse(_ text: String, now: Date = Date()) -> RawBankEvent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // The OTP check runs once here; the grammar is told not to repeat it.
        if IndianBankSMSGrammar.looksLikeOTP(trimmed) { return nil }

        if let captured = IndianBankSMSGrammar.parse(trimmed, now: now, checkOTP: false) {
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
            accountLast4: firstGroup(last4Regex, in: trimmed) ?? "",
            merchant: draft.merchant,
            externalRef: firstGroup(utrRegex, in: trimmed),
            occurredAt: draft.date,
            bank: "Unknown",
            source: .smsImport,
            confidence: min(0.45, draft.confidence)
        )
    }

    private static func firstGroup(_ regex: NSRegularExpression?, in text: String) -> String? {
        guard let regex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let hit = regex.firstMatch(in: text, range: range), let r = Range(hit.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}

@MainActor
enum BankImportPipeline {
    static let reviewThreshold = 0.7
    /// Duplicate and rejected rows older than this are deleted on the next SMS drain.
    static let staleRowRetentionDays = 90

    /// Refs and hashes seen in the current batch, so a batch can dedupe before its single save.
    private final class Batch {
        var refs: Set<String> = []
        var hashes: Set<String> = []
    }

    @discardableResult
    static func ingest(_ event: RawBankEvent, in context: ModelContext) -> ImportedEvent? {
        ingest(event, in: context, batch: nil)
    }

    private static func ingest(_ event: RawBankEvent, in context: ModelContext, batch: Batch?) -> ImportedEvent? {
        let hash = rawHash(for: event)
        let duplicate = isDuplicate(event, hash: hash, in: context)
            || batch.map { batch in
                batch.hashes.contains(hash) || (event.externalRef.map { batch.refs.contains($0) } ?? false)
            } ?? false
        if let batch {
            batch.hashes.insert(hash)
            if let ref = event.externalRef { batch.refs.insert(ref) }
        }
        if duplicate {
            let row = ImportedEvent(event: event, hash: hash, categoryName: "Duplicate")
            row.status = .duplicate
            context.insert(row)
            saveUnlessBatched(context, batch: batch)
            return row
        }
        let resolved = resolution(for: event, in: context)
        var display = event
        display.merchant = resolved.merchant
        func makeRow() -> ImportedEvent {
            let row = ImportedEvent(event: display, hash: hash, categoryName: resolved.categoryName)
            row.payeeKey = resolved.payeeKey
            row.personName = resolved.personName
            row.needsPayeeChoice = resolved.needsChoice
            return row
        }
        let row = makeRow()
        if resolved.needsChoice || event.confidence < reviewThreshold {
            row.status = .pendingReview
            context.insert(row)
            saveUnlessBatched(context, batch: batch)
            return row
        }
        if post(row, in: context, saving: batch == nil) {
            return row
        }
        // A failed post may have rolled the context back with `row` in it, so the
        // review row is a fresh object rather than a re-insert of a discarded one.
        let pending = makeRow()
        pending.status = .pendingReview
        context.insert(pending)
        saveUnlessBatched(context, batch: batch)
        return pending
    }

    /// Drains the shared SMS inbox, ingests every message, then saves once.
    static func ingestCapturedSMS(in context: ModelContext) {
        let texts = SMSInbox.drain()
        guard !texts.isEmpty else { return }
        ingestBatch(texts, in: context)
    }

    /// Ingests several SMS bodies with one save at the end. Returns the rows created.
    @discardableResult
    static func ingestBatch(_ texts: [String], in context: ModelContext, now: Date = Date()) -> [ImportedEvent] {
        let batch = Batch()
        var rows: [ImportedEvent] = []
        for text in texts {
            guard let event = BankSMSParser.parse(text) else { continue }
            if let row = ingest(event, in: context, batch: batch) { rows.append(row) }
        }
        purgeStaleRows(in: context, now: now)
        do {
            try Ledger.save(context)
        } catch {
            // Same as before: the rows stay pending in the context and the next save retries them.
        }
        return rows
    }

    static func ingestSMS(_ text: String, in context: ModelContext) -> ImportedEvent? {
        guard let event = BankSMSParser.parse(text) else { return nil }
        return ingest(event, in: context)
    }

    /// Deletes duplicate and rejected rows whose message is older than `staleRowRetentionDays`.
    /// Pending and posted rows are kept. Does not save.
    static func purgeStaleRows(in context: ModelContext, now: Date = Date()) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -staleRowRetentionDays, to: now) else { return }
        let duplicate = ImportEventStatus.duplicate.rawValue
        let rejected = ImportEventStatus.rejected.rawValue
        let descriptor = FetchDescriptor<ImportedEvent>(predicate: #Predicate {
            $0.occurredAt < cutoff && ($0.statusRaw == duplicate || $0.statusRaw == rejected)
        })
        for row in (try? context.fetch(descriptor)) ?? [] {
            context.delete(row)
        }
    }

    private static func saveUnlessBatched(_ context: ModelContext, batch: Batch?) {
        guard batch == nil else { return }
        try? Ledger.save(context)
    }

    /// Stores the user's label for this person and posts the debit. A later SMS to the same VPA or name reuses it.
    @discardableResult
    static func remember(_ row: ImportedEvent, as choice: PayeeChoice, in context: ModelContext) -> Bool {
        guard row.status == .pendingReview, row.needsPayeeChoice, !row.payeeKey.isEmpty else { return false }
        let title = choice.title(person: row.personName)
        let created: RememberedPayee?
        if let existing = rememberedPayee(forKey: row.payeeKey, in: context) {
            existing.label = choice.label
            existing.personName = row.personName
            existing.categoryName = choice.categoryName
            existing.displayTitle = title
            created = nil
        } else {
            let payee = RememberedPayee(
                payeeKey: row.payeeKey,
                label: choice.label,
                personName: row.personName,
                categoryName: choice.categoryName,
                displayTitle: title
            )
            context.insert(payee)
            created = payee
        }
        let previousMerchant = row.merchant
        row.merchant = title
        row.categoryName = choice.categoryName
        row.needsPayeeChoice = false
        if post(row, in: context) { return true }
        row.merchant = previousMerchant
        row.needsPayeeChoice = true
        if let created { context.delete(created) }
        return false
    }

    private struct PayeeResolution {
        var merchant: String
        var categoryName: String
        var payeeKey: String
        var personName: String
        var needsChoice: Bool
    }

    private static func rememberedPayee(forKey key: String, in context: ModelContext) -> RememberedPayee? {
        var descriptor = FetchDescriptor<RememberedPayee>(predicate: #Predicate { $0.payeeKey == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func resolution(for event: RawBankEvent, in context: ModelContext) -> PayeeResolution {
        let raw = event.merchant ?? ""
        let key = MerchantDirectory.payeeKey(from: raw)
        if !key.isEmpty {
            if let match = rememberedPayee(forKey: key, in: context) {
                return PayeeResolution(
                    merchant: match.displayTitle,
                    categoryName: match.categoryName,
                    payeeKey: key,
                    personName: match.personName,
                    needsChoice: false
                )
            }
        }
        if let company = MerchantDirectory.company(in: raw) {
            return PayeeResolution(
                merchant: company.displayName,
                categoryName: company.categoryName,
                payeeKey: key,
                personName: "",
                needsChoice: false
            )
        }
        if MerchantDirectory.isPersonPayee(raw) {
            let person = MerchantDirectory.personName(from: raw)
            return PayeeResolution(
                merchant: person,
                categoryName: ExpenseCategory.otherCategoryName,
                payeeKey: key,
                personName: person,
                needsChoice: true
            )
        }
        // Only the merchant/category classifier is needed here, not the amount and date rules.
        let guess = ExpenseParsingService.shared.classify(raw.isEmpty ? event.bank : raw)
        return PayeeResolution(
            merchant: raw.isEmpty ? (guess.merchant ?? event.bank) : raw,
            categoryName: guess.categoryName,
            payeeKey: key,
            personName: "",
            needsChoice: false
        )
    }

    @discardableResult
    static func approve(_ row: ImportedEvent, in context: ModelContext) -> Bool {
        guard row.status == .pendingReview, !row.needsPayeeChoice else { return false }
        return post(row, in: context)
    }

    static func reject(_ row: ImportedEvent, in context: ModelContext) {
        row.status = .rejected
        try? Ledger.save(context, rollbackOnFailure: true)
    }

    static func deleteAggregatorImports(in context: ModelContext) {
        let source = TransactionEntrySource.aggregator.rawValue
        let events = (try? context.fetch(FetchDescriptor<ImportedEvent>(predicate: #Predicate { $0.sourceRaw == source }))) ?? []
        let txs = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.entrySourceRaw == source }))) ?? []
        var touched: [String: Account] = [:]
        for tx in txs where tx.countsInLedger {
            if let account = tx.account ?? account(id: tx.accountId, in: context) {
                touched[account.id] = account
            }
        }
        try? Ledger.commit(context, touching: Array(touched.values)) {
            for event in events { context.delete(event) }
            for tx in txs {
                if tx.countsInLedger, let account = tx.account ?? touched[tx.accountId] {
                    Ledger.apply(tx.isCredit ? -tx.amount : tx.amount, to: account)
                }
                context.delete(tx)
            }
        }
    }

    private static func account(id: String, in context: ModelContext) -> Account? {
        var descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func post(_ row: ImportedEvent, in context: ModelContext, saving: Bool = true) -> Bool {
        let declared = (try? context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.bankName != "" }))) ?? []
        guard let account = Account.match(last4: row.accountLast4, bank: row.bank, among: declared) else {
            return false
        }
        return recordLabeled(row, on: account, in: context, saving: saving)
    }

    /// Files the expense on the account the user named. Does not change that account's balance:
    /// the last digits are not a link to the bank, so there is no balance to move.
    /// - Parameter saving: `false` inside a batch, which saves once at the end.
    /// When saving, a failed save rolls the context back and returns `false`.
    private static func recordLabeled(_ row: ImportedEvent, on account: Account, in context: ModelContext, saving: Bool) -> Bool {
        if AuthenticationService.movementBlocked { return false }
        if let ref = row.externalRef, !ref.isEmpty, transactionExists(withRef: ref, in: context) {
            return false
        }
        let isCredit = row.directionRaw == ImportDirection.credit.rawValue
        let tx = Transaction(
            accountId: account.id,
            type: isCredit ? .deposit : .payment,
            amount: row.amount,
            currency: account.currency,
            description: row.merchant.isEmpty ? (isCredit ? "Imported credit" : "Imported payment") : row.merchant,
            referenceNumber: row.externalRef,
            transactionDate: row.occurredAt,
            category: row.categoryName,
            merchant: row.merchant,
            entrySource: row.source
        )
        tx.externalRef = row.externalRef
        tx.rawHash = row.rawHash
        tx.countsInLedger = false
        tx.railRaw = PaymentRail.imported.rawValue
        tx.categoryRef = category(named: row.categoryName, in: context)
        tx.account = account
        context.insert(tx)
        row.status = .posted
        if row.modelContext == nil { context.insert(row) }
        guard saving else { return true }
        do {
            try Ledger.save(context, rollbackOnFailure: true)
            return true
        } catch {
            return false
        }
    }

    private static func transactionExists(withRef ref: String, in context: ModelContext) -> Bool {
        var byExternal = FetchDescriptor<Transaction>(predicate: #Predicate { $0.externalRef == ref })
        byExternal.fetchLimit = 1
        if let hit = try? context.fetch(byExternal), !hit.isEmpty { return true }
        var byReference = FetchDescriptor<Transaction>(predicate: #Predicate { $0.referenceNumber == ref })
        byReference.fetchLimit = 1
        if let hit = try? context.fetch(byReference), !hit.isEmpty { return true }
        return false
    }

    private static func isDuplicate(_ event: RawBankEvent, hash: String, in context: ModelContext) -> Bool {
        if let ref = event.externalRef {
            let rejected = ImportEventStatus.rejected.rawValue
            var byRef = FetchDescriptor<ImportedEvent>(predicate: #Predicate { $0.externalRef == ref && $0.statusRaw != rejected })
            byRef.fetchLimit = 1
            if let hit = try? context.fetch(byRef), !hit.isEmpty { return true }
        }
        var byHash = FetchDescriptor<ImportedEvent>(predicate: #Predicate { $0.rawHash == hash })
        byHash.fetchLimit = 1
        if let hit = try? context.fetch(byHash), !hit.isEmpty { return true }
        if let ref = event.externalRef, transactionExists(withRef: ref, in: context) {
            return true
        }
        // Fuzzy match only looks at rows within the 180-second window.
        let earliest = event.occurredAt.addingTimeInterval(-180)
        let latest = event.occurredAt.addingTimeInterval(180)
        let nearby = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate {
            $0.transactionDate > earliest && $0.transactionDate < latest
        }))) ?? []
        return nearby.contains { tx in
            tx.amount == event.amount
                && abs(tx.transactionDate.timeIntervalSince(event.occurredAt)) < 180
                && (tx.account.map { String($0.accountNumber.suffix(4)) } == event.accountLast4)
                && Account.sameBank(tx.account?.bankName ?? "", event.bank)
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
        return CryptoService.receiptHash(for: payload)
    }
}
