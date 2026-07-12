import Foundation
import SwiftData

/// Codable value type embedded directly on `User`. SwiftData persists Codable
/// structs as a single encoded attribute, so this does not need its own `@Model`.
nonisolated struct Address: Codable, Hashable {
    var street: String = ""
    var city: String = ""
    var state: String = ""
    var postalCode: String = ""
    var country: String = ""
}

@Model
nonisolated final class User {
    var id: String = UUID().uuidString
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var phoneNumber: String = ""
    var dateOfBirth: Date = Date()
    var address: Address = Address()
    var isActive: Bool = true
    var createdAt: Date = Date()
    var lastLogin: Date?

    init(
        id: String = UUID().uuidString,
        firstName: String,
        lastName: String,
        email: String,
        phoneNumber: String,
        dateOfBirth: Date,
        address: Address,
        isActive: Bool = true,
        createdAt: Date = Date(),
        lastLogin: Date? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.dateOfBirth = dateOfBirth
        self.address = address
        self.isActive = isActive
        self.createdAt = createdAt
        self.lastLogin = lastLogin
    }

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}
