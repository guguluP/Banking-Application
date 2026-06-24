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
    let amount: Decimal
    let currency: String
    let description: String
    let counterparty: String?
    let referenceNumber: String?
    let transactionDate: Date
    let category: String?
    let location: String?
    var status: TransactionStatus = .completed
    var postingDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountId
        case type = "transactionType"
        case amount
        case currency
        case description
        case counterparty
        case referenceNumber
        case transactionDate
        case category
        case location
        case status
        case postingDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        accountId = try container.decode(String.self, forKey: .accountId)
        type = try container.decode(TransactionType.self, forKey: .type)
        amount = try container.decode(Decimal.self, forKey: .amount)
        description = try container.decode(String.self, forKey: .description)
        transactionDate = try container.decode(Date.self, forKey: .transactionDate)
        currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "INR"
        counterparty = try container.decodeIfPresent(String.self, forKey: .counterparty)
        referenceNumber = try container.decodeIfPresent(String.self, forKey: .referenceNumber)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        status = try container.decodeIfPresent(TransactionStatus.self, forKey: .status) ?? .completed
        postingDate = try container.decodeIfPresent(Date.self, forKey: .postingDate)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(type, forKey: .type)
        try container.encode(amount, forKey: .amount)
        try container.encode(currency, forKey: .currency)
        try container.encode(description, forKey: .description)
        try container.encode(counterparty, forKey: .counterparty)
        try container.encode(referenceNumber, forKey: .referenceNumber)
        try container.encode(transactionDate, forKey: .transactionDate)
        try container.encode(category, forKey: .category)
        try container.encode(location, forKey: .location)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(postingDate, forKey: .postingDate)
    }
    
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