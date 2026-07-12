import Foundation
import SwiftData

@Model
nonisolated final class Biller {
    var id: String = UUID().uuidString
    var userId: String = ""
    var name: String = ""
    var accountNumber: String = ""
    var billerCode: String?
    var nickname: String?
    var address: Address?
    var phoneNumber: String?
    var email: String?
    var website: String?
    var isFavorite: Bool = false
    var createdAt: Date = Date()

    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        accountNumber: String,
        billerCode: String? = nil,
        nickname: String? = nil,
        address: Address? = nil,
        phoneNumber: String? = nil,
        email: String? = nil,
        website: String? = nil,
        isFavorite: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.accountNumber = accountNumber
        self.billerCode = billerCode
        self.nickname = nickname
        self.address = address
        self.phoneNumber = phoneNumber
        self.email = email
        self.website = website
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }

    var displayName: String {
        nickname ?? name
    }
}
