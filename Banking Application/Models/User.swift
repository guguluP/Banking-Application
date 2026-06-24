import Foundation

struct User: Identifiable, Codable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let phoneNumber: String
    let dateOfBirth: Date
    let address: Address
    let isActive: Bool
    let createdAt: Date
    let lastLogin: Date?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

struct Address: Codable, Hashable {
    let street: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
}