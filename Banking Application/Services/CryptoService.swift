import Foundation
import CryptoKit
import CommonCrypto
import Security

/// Handles one-way hashing for the app passcode. The passcode itself is never
/// stored anywhere — only a PBKDF2-HMAC-SHA256 digest is persisted (in the Keychain,
/// via `AuthenticationService`).
///
nonisolated enum CryptoService {
    static let pbkdfRounds: UInt32 = 120_000

    /// Generates a new random 32-byte salt, base64-encoded for storage.
    static func generateSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    /// PBKDF2-HMAC-SHA256. Stored hashes from the older single SHA-256 are still
    /// accepted by `verify`, which upgrades them on the next successful check.
    static func hash(passcode: String, salt: String) -> String {
        let saltBytes = Array(Data(salt.utf8))
        let password = Array(passcode.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            password,
            password.count,
            saltBytes,
            saltBytes.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            pbkdfRounds,
            &derived,
            derived.count
        )
        guard status == kCCSuccess else { return legacyHash(passcode: passcode, salt: salt) }
        return "pbkdf2$\(pbkdfRounds)$\(hexString(derived))"
    }

    static func legacyHash(passcode: String, salt: String) -> String {
        let combined = Data((passcode + salt).utf8)
        return hexString(SHA256.hash(data: combined))
    }

    static func verify(passcode: String, salt: String, storedHash: String) -> Bool {
        if storedHash.hasPrefix("pbkdf2$") {
            return constantTimeEquals(hash(passcode: passcode, salt: salt), storedHash)
        }
        return constantTimeEquals(legacyHash(passcode: passcode, salt: salt), storedHash)
    }

    /// Lowercase hex SHA-256 of `payload`. Used for receipts and import dedupe hashes.
    static func receiptHash(for payload: String) -> String {
        hexString(SHA256.hash(data: Data(payload.utf8)))
    }

    private static let hexDigits = Array("0123456789abcdef".utf8)

    /// Lowercase, zero-padded hex for a byte sequence — the same output as
    /// `map { String(format: "%02x", $0) }.joined()`, without a formatter per byte.
    static func hexString<Bytes: Sequence>(_ bytes: Bytes) -> String where Bytes.Element == UInt8 {
        var utf8: [UInt8] = []
        utf8.reserveCapacity(bytes.underestimatedCount * 2)
        for byte in bytes {
            utf8.append(hexDigits[Int(byte >> 4)])
            utf8.append(hexDigits[Int(byte & 0x0f)])
        }
        return String(decoding: utf8, as: UTF8.self)
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
