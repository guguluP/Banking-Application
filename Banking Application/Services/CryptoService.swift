import Foundation
import CryptoKit
import Security

/// Handles one-way hashing for the app passcode. The passcode itself is never
/// stored anywhere — only a salted SHA-256 digest is persisted (in the Keychain,
/// via `AuthenticationService`). This means even a full device-storage extraction
/// cannot recover the original passcode.
enum CryptoService {

    /// Generates a new random 32-byte salt, base64-encoded for storage.
    static func generateSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    /// Produces a hex-encoded SHA-256 hash of `passcode + salt`.
    static func hash(passcode: String, salt: String) -> String {
        let combined = Data((passcode + salt).utf8)
        let digest = SHA256.hash(data: combined)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Constant-time comparison to avoid leaking timing information about how
    /// many characters of a guessed hash matched.
    static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        guard lhs.utf8.count == rhs.utf8.count else { return false }
        var result: UInt8 = 0
        for (a, b) in zip(lhs.utf8, rhs.utf8) {
            result |= a ^ b
        }
        return result == 0
    }
}
