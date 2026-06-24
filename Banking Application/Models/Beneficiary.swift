import Foundation

struct Beneficiary: Identifiable, Codable {
    let id: String
    let userId: String
    let nickname: String
    let accountNumber: String
    let bankName: String
    let bankCode: String? // Routing number, SWIFT, etc.
    let accountType: AccountType
    let isFavorite: Bool
    let createdAt: Date
    
    var displayName: String {
        return "\(nickname) (\(accountNumber.suffix(4)))"
    }
}