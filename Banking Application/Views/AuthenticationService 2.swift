import Foundation
import SwiftData

final class AuthenticationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated: Bool = false
    @Published var hasPasscodeConfigured: Bool = false
    @Published var user: UserProfile? = nil
    
    // MARK: - UserProfile
    
    struct UserProfile: Identifiable, Codable {
        var id: UUID
        var firstName: String
        var lastName: String
        var email: String
    }
    
    // MARK: - Initialization
    
    init() {
        self.isAuthenticated = false
        self.hasPasscodeConfigured = false
        self.user = nil
    }
    
    // MARK: - Authentication Methods
    
    func signIn(firstName: String, lastName: String, email: String) {
        let newUser = UserProfile(id: UUID(), firstName: firstName, lastName: lastName, email: email)
        self.user = newUser
        self.isAuthenticated = true
    }
    
    func signOut() {
        self.user = nil
        self.isAuthenticated = false
    }
    
    func configurePasscode() {
        self.hasPasscodeConfigured = true
    }
    
    // MARK: - User Loading
    
    func loadUser(from container: ModelContainer) {
        if self.user == nil {
            self.user = UserProfile(id: UUID(), firstName: "Alex", lastName: "Doe", email: "alex@example.com")
            self.isAuthenticated = true
        }
    }
}
