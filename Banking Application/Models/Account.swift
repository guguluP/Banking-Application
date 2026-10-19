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
    /// Bank the user named at login, such as "HDFC Bank". Empty for older demo rows.
    var bankName: String = ""

    /// History stays when an account row is removed so the ledger can still be audited.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.account)
    var transactions: [Transaction]? = []

    /// Balance before rows with `countsInLedger == true`. Existing demo rows are
    /// folded into this figure once, so they are not applied twice.
    var openingBalance: Decimal = 0
    /// Difference between book balance and spendable balance (holds).
    var reservedHold: Decimal = 0
    var usesLedgerBalance: Bool = false

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

    /// The user named this account (bank + last digits) so expenses can be filed on it.
    /// The balance is not the balance at that bank.
    var isDeclaredSpendAccount: Bool {
        !bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// "HDFC Bank · 4521", or the nickname when this row was not declared at login.
    var expenseAccountLabel: String {
        let last4 = String(accountNumber.suffix(4))
        let bank = bankName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !bank.isEmpty { return "\(bank) · \(last4)" }
        if let nickname, !nickname.isEmpty { return nickname }
        return "\(accountType.rawValue) · \(last4)"
    }

    /// Catalog name when `name` is exactly a bank name or alias. Otherwise the trimmed text.
    static func canonicalBank(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        guard !lower.isEmpty else { return "" }
        if let exact = IndianBankCatalog.banks.first(where: { bank in
            bank.name.lowercased() == lower || bank.aliases.contains(lower)
        }) {
            return exact.name
        }
        return trimmed
    }

    static func sameBank(_ lhs: String, _ rhs: String) -> Bool {
        let left = canonicalBank(lhs)
        let right = canonicalBank(rhs)
        guard !left.isEmpty, !right.isEmpty else { return false }
        return left.caseInsensitiveCompare(right) == .orderedSame
    }

    /// A bank string that should decide the match. "Unknown" and the local sandbox do not.
    static func bankIsSpecific(_ name: String) -> Bool {
        let lower = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !lower.isEmpty && lower != "unknown" && lower != "sandbox"
    }

    /// Declared account for this expense. A named bank must match the bank and the last four digits.
    /// An unnamed bank matches only when one declared account has those digits.
    static func match(last4: String, bank: String, among accounts: [Account]) -> Account? {
        let digits = String(last4.filter(\.isNumber).suffix(4))
        guard digits.count == 4 else { return nil }
        let candidates = accounts.filter {
            $0.isDeclaredSpendAccount && String($0.accountNumber.suffix(4)) == digits
        }
        if bankIsSpecific(bank) {
            return candidates.first { sameBank($0.bankName, bank) }
        }
        return candidates.count == 1 ? candidates[0] : nil
    }
}
