import Foundation

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

struct Transaction: Identifiable, Codable {
    let id: String
    let accountId: String
    let type: TransactionType
    let status: TransactionStatus
    let amount: Decimal
    let currency: String
    let description: String
    let counterparty: String?
    let referenceNumber: String?
    let transactionDate: Date
    let postingDate: Date
    let category: String?
    let location: String?
    
    var formattedAmount: String {
        CurrencyFormatter.shared.string(from: amount, showSign: true, for: type)
    }
    
    var isCredit: Bool {
        return type == .deposit || type == .interest
    }
    
    var isDebit: Bool {
        return type == .withdrawal || type == .payment || type == .fee || (type == .transfer && amount.sign == .minus)
    }
}