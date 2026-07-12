import Foundation
import SwiftData

@Model
nonisolated final class Beneficiary {
    var id: String = UUID().uuidString
    var userId: String = ""
    var nickname: String = ""
    var accountNumber: String = ""
    var bankName: String = ""
    var bankCode: String? // Routing number, SWIFT, etc.
    var accountTypeRaw: String = AccountType.checking.rawValue
    var isFavorite: Bool = false
    var createdAt: Date = Date()

    var accountType: AccountType {
        get { AccountType(rawValue: accountTypeRaw) ?? .checking }
        set { accountTypeRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        userId: String,
        nickname: String,
        accountNumber: String,
        bankName: String,
        bankCode: String? = nil,
        accountType: AccountType,
        isFavorite: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.nickname = nickname
        self.accountNumber = accountNumber
        self.bankName = bankName
        self.bankCode = bankCode
        self.accountTypeRaw = accountType.rawValue
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }

    var displayName: String {
        "\(nickname) (\(accountNumber.suffix(4)))"
    }
}
