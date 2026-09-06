import Foundation
import SwiftData
import Combine

final class AuthenticationService: ObservableObject {
    // Represents the signed-in user. Replace `UserProfile` with your app's actual user model if available.
    @Published var user: UserProfile?
    @Published var isAuthenticated: Bool = false
    @Published var hasPasscodeConfigured: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {}

    // Stub method to load the current user from a SwiftData container.
    // Adjust the fetch to your real model when available.
    func loadUser(from container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<UserProfile>(predicate: nil)
        if let existing = try? context.fetch(descriptor).first {
            self.user = existing
            self.isAuthenticated = true
        }
    }

    // MARK: - Session control stubs

    func login(with user: UserProfile) {
        self.user = user
        self.isAuthenticated = true
    }

    func logout() {
        self.isAuthenticated = false
        self.user = nil
    }

    func configurePasscode(_ configured: Bool) {
        self.hasPasscodeConfigured = configured
    }
}

// Minimal placeholder user type so the project compiles. If you already have a user model, delete this and use yours.
@Model
final class UserProfile: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
