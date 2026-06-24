import Foundation

enum AccountType: String, Codable, CaseIterable {
    case checking = "Checking"
    case savings = "Savings"
    case credit = "Credit Card"
    case loan = "Loan"
    case investment = "Investment"
}

enum AccountStatus: String, Codable {
    case active = "Active"
    case inactive = "Inactive"
    case frozen = "Frozen"
    case closed = "Closed"
}

struct Account: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let accountNumber: String
    let accountType: AccountType
    let accountStatus: AccountStatus
    let balance: Decimal
    let availableBalance: Decimal
    let currency: String
    let nickname: String?
    let openedDate: Date
    let interestRate: Double?
    let isPrimary: Bool
    
    var formattedBalance: String {
        CurrencyFormatter.shared.string(from: balance)
    }
    
    var formattedAvailableBalance: String {
        CurrencyFormatter.shared.string(from: availableBalance)
    }
}