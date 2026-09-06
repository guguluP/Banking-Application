import Foundation
import SwiftData

enum TransactionType: String, Codable {
    case deposit = "Deposit"
    case withdrawal = "Withdrawal"
    case transfer = "Transfer"
    case payment = "Payment"
    case fee = "Fee"
    case interest = "Interest"
}

enum TransactionStatus: String, Codable {
    case pending = "Pending"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

enum TransactionEntrySource: String, Codable {
    /// Produced by the app's existing simulated banking flows (transfer,
    /// UPI, bill pay, seed data) — unrelated to Windfall-style tracking.
    case system = "System"
    case manualEntry = "Manual Entry"
    case naturalLanguage = "Natural Language"
    case receiptScan = "Receipt Scan"
}

@Model
nonisolated final class Transaction {
    var id: String = UUID().uuidString
    var accountId: String = ""
    var typeRaw: String = TransactionType.payment.rawValue
    var amount: Decimal = 0
    var currency: String = "INR"
    var transactionDescription: String = ""
    var counterparty: String?
    var referenceNumber: String?
    var transactionDate: Date = Date()
    /// Legacy free-text category, kept for backward compatibility with rows
    /// written before `ExpenseCategory` existed and for banking flows (bill
    /// pay, transfers) that still just want a display label. New
    /// expense-tracking entries should set `categoryRef` instead; `category`
    /// is kept in sync with `categoryRef?.name` for those so every existing
    /// list/filter that reads the string still works unmodified.
    var category: String?
    var location: String?
    var statusRaw: String = TransactionStatus.completed.rawValue
    var postingDate: Date?

    /// The merchant or payee name as understood by manual/NL/OCR entry —
    /// distinct from `transactionDescription`, which may be a fuller note
    /// ("Coffee and a croissant") rather than a clean merchant name.
    var merchant: String?
    var entrySourceRaw: String = TransactionEntrySource.system.rawValue
    /// Set only for `.receiptScan` entries; the original photo, kept so the
    /// user can review what was scanned. Local storage only — never
    /// uploaded anywhere.
    @Attribute(.externalStorage)
    var receiptImageData: Data?
    /// 0...1 confidence from the NL/OCR extraction pipeline for the
    /// weakest field it had to infer (usually category or amount). `nil`
    /// for manual and system entries, which have no extraction to be
    /// unsure about.
    var extractionConfidence: Double?
    var notes: String?

    // Inverse of Account.transactions. Optional, as CloudKit-backed SwiftData
    // relationships must not be required.
    var account: Account?
    var categoryRef: ExpenseCategory?

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .payment }
        set { typeRaw = newValue.rawValue }
    }

    var status: TransactionStatus {
        get { TransactionStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    var entrySource: TransactionEntrySource {
        get { TransactionEntrySource(rawValue: entrySourceRaw) ?? .system }
        set { entrySourceRaw = newValue.rawValue }
    }

    /// Kept as `description` at the call site via this computed alias, since
    /// `description` is reserved by `CustomStringConvertible` on NSObject-adjacent
    /// types; the stored property above avoids that collision.
    var description: String {
        get { transactionDescription }
        set { transactionDescription = newValue }
    }

    init(
        id: String = UUID().uuidString,
        accountId: String,
        type: TransactionType,
        amount: Decimal,
        currency: String = "INR",
        description: String,
        counterparty: String? = nil,
        referenceNumber: String? = nil,
        transactionDate: Date = Date(),
        category: String? = nil,
        location: String? = nil,
        status: TransactionStatus = .completed,
        postingDate: Date? = nil,
        merchant: String? = nil,
        entrySource: TransactionEntrySource = .system,
        receiptImageData: Data? = nil,
        extractionConfidence: Double? = nil,
        notes: String? = nil,
        categoryRef: ExpenseCategory? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.typeRaw = type.rawValue
        self.amount = amount
        self.currency = currency
        self.transactionDescription = description
        self.counterparty = counterparty
        self.referenceNumber = referenceNumber
        self.transactionDate = transactionDate
        self.category = category
        self.location = location
        self.statusRaw = status.rawValue
        self.postingDate = postingDate
        self.merchant = merchant
        self.entrySourceRaw = entrySource.rawValue
        self.receiptImageData = receiptImageData
        self.extractionConfidence = extractionConfidence
        self.notes = notes
        self.categoryRef = categoryRef
    }

    var formattedAmount: String {
        CurrencyFormatter.shared.string(from: amount, showSign: true, for: type)
    }

    /// Money into the account. Incoming funds must use `.deposit` or
    /// `.interest` — amounts are always stored unsigned, so `.transfer`
    /// always means an outgoing debit (`TransferViewModel.performTransfer`).
    var isCredit: Bool {
        type == .deposit || type == .interest
    }

    /// Money out of the account. Complements `isCredit` so callers do not
    /// reinvent `!isCredit` (and so a future incoming-transfer type cannot
    /// silently land in spending charts).
    var isDebit: Bool {
        !isCredit
    }

    /// True for rows created through the Track tab (Quick-Add, NL entry, or
    /// receipt scan) as opposed to the app's simulated banking flows —
    /// controls whether a transaction shows up in the Track ledger/budget
    /// math versus just the general Account activity feed.
    var isExpenseTrackerEntry: Bool {
        entrySource != .system
    }
}
