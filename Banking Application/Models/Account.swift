import Foundation
import SwiftData

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

/// Persisted locally with SwiftData and synced across the user's devices via
/// CloudKit's private database (see `PersistenceController`). Every property has a
/// default value, and there are no `.unique` constraints, both of which are
/// required for a SwiftData model to be CloudKit-eligible.
@Model
nonisolated final class Account {
    var id: String = UUID().uuidString
    var userId: String = ""
    var accountNumber: String = ""
    var accountTypeRaw: String = AccountType.checking.rawValue
    var accountStatusRaw: String = AccountStatus.active.rawValue
    var balance: Decimal = 0
    var availableBalance: Decimal = 0
    var currency: String = "INR"
    var nickname: String?
    var openedDate: Date = Date()
    var interestRate: Double?
    var isPrimary: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]? = []

    var accountType: AccountType {
        get { AccountType(rawValue: accountTypeRaw) ?? .checking }
        set { accountTypeRaw = newValue.rawValue }
    }

    var accountStatus: AccountStatus {
        get { AccountStatus(rawValue: accountStatusRaw) ?? .active }
        set { accountStatusRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        userId: String,
        accountNumber: String,
        accountType: AccountType,
        accountStatus: AccountStatus = .active,
        balance: Decimal,
        availableBalance: Decimal,
        currency: String = "INR",
        nickname: String? = nil,
        openedDate: Date = Date(),
        interestRate: Double? = nil,
        isPrimary: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.accountNumber = accountNumber
        self.accountTypeRaw = accountType.rawValue
        self.accountStatusRaw = accountStatus.rawValue
        self.balance = balance
        self.availableBalance = availableBalance
        self.currency = currency
        self.nickname = nickname
        self.openedDate = openedDate
        self.interestRate = interestRate
        self.isPrimary = isPrimary
    }

    var formattedBalance: String {
        CurrencyFormatter.shared.string(from: balance)
    }

    var formattedAvailableBalance: String {
        CurrencyFormatter.shared.string(from: availableBalance)
    }
}
