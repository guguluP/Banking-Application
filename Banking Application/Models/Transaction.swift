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
    var category: String?
    var location: String?
    var statusRaw: String = TransactionStatus.completed.rawValue
    var postingDate: Date?

    // Inverse of Account.transactions. Optional, as CloudKit-backed SwiftData
    // relationships must not be required.
    var account: Account?

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .payment }
        set { typeRaw = newValue.rawValue }
    }

    var status: TransactionStatus {
        get { TransactionStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
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
        postingDate: Date? = nil
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
    }

    var formattedAmount: String {
        CurrencyFormatter.shared.string(from: amount, showSign: true, for: type)
    }

    var isCredit: Bool {
        type == .deposit || type == .interest
    }

    var isDebit: Bool {
        type == .withdrawal || type == .payment || type == .fee || (type == .transfer && amount.sign == .minus)
    }
}
