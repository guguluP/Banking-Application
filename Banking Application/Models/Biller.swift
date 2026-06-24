import Foundation

struct Biller: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let name: String
    let accountNumber: String
    let billerCode: String?
    let nickname: String?
    let address: Address?
    let phoneNumber: String?
    let email: String?
    let website: String?
    let isFavorite: Bool
    let createdAt: Date
    
    init(id: String, userId: String, name: String, accountNumber: String, billerCode: String? = nil, nickname: String? = nil, address: Address? = nil, phoneNumber: String? = nil, email: String? = nil, website: String? = nil, isFavorite: Bool = false, createdAt: Date = Date()) {
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
        return nickname ?? name
    }
}