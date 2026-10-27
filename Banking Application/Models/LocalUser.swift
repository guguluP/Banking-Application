import Foundation

/// The single on-device profile this app keeps. Every locally created row is
/// owned by this id until a real multi-user identity model exists.
nonisolated enum LocalUser {
    static let id = "user_001"
}
