import Foundation
import Security
import LocalAuthentication

/// A thin, dependency-free wrapper around the Keychain Services API.
///
/// All sensitive values in the app (passcode hash, passcode salt, failed-attempt
/// counters, session tokens) are stored here instead of `UserDefaults`, which is an
/// unencrypted property list and must never be used for credentials.
///
/// Items are stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, meaning they:
///   - are encrypted at rest using the device's Secure Enclave-backed keys,
///   - are only readable while the device is unlocked,
///   - never sync to iCloud Keychain or get included in device backups.
/// Reads and writes the lockout clock without requiring the real Keychain.
/// Tests use `MemoryLockoutStore` because a CI simulator often rejects
/// `SecItemAdd` for an unsigned host.
protocol LockoutStore: AnyObject {
    func getString(forKey key: String) -> String?
    @discardableResult func set(_ string: String, forKey key: String) -> Bool
}

final class MemoryLockoutStore: LockoutStore {
    private var values: [String: String] = [:]

    func getString(forKey key: String) -> String? { values[key] }

    @discardableResult
    func set(_ string: String, forKey key: String) -> Bool {
        values[key] = string
        return true
    }
}

final class KeychainService {

    static let shared = KeychainService()

    private init() {}

    enum KeychainError: LocalizedError {
        case unexpectedStatus(OSStatus)
        case dataConversionFailed

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                return "Keychain error (\(status))"
            case .dataConversionFailed:
                return "Could not convert value for secure storage."
            }
        }
    }

    private let service = "com.banksecure.app"

    // MARK: - Generic Data API

    @discardableResult
    func set(_ data: Data, forKey key: String) -> Bool {
        var query = baseQuery(for: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        // Remove any existing item first so this behaves as an upsert.
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func getData(forKey key: String) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - String convenience

    @discardableResult
    func set(_ string: String, forKey key: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return set(data, forKey: key)
    }

    func getString(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Int convenience (used for failed-attempt counters)

    @discardableResult
    func set(_ value: Int, forKey key: String) -> Bool {
        set(String(value), forKey: key)
    }

    func getInt(forKey key: String) -> Int? {
        guard let string = getString(forKey: key) else { return nil }
        return Int(string)
    }

    // MARK: - Helpers

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    /// Wipes every secure item this app owns. Called on logout-and-erase or when a
    /// new passcode is being provisioned from scratch.
    /// Stores a random secret that the system will reveal only after a biometric
    /// match against the current set. A failed match or a simulator without
    /// biometrics returns false and the caller falls back to the app passcode.
    @discardableResult
    func installBiometricGate() -> Bool {
        delete(forKey: KeychainKey.biometricGate)
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else { return false }
        let secret = Data(UUID().uuidString.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: KeychainKey.biometricGate,
            kSecValueData as String: secret,
            kSecAttrAccessControl as String: access
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func readBiometricGate(reason: String) -> Bool {
        let context = LAContext()
        context.localizedReason = reason
        var query = baseQuery(for: KeychainKey.biometricGate)
        query[kSecReturnData as String] = true
        query[kSecUseAuthenticationContext as String] = context
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess && result is Data
    }

    func removeAll() {
        let classes: [CFString] = [kSecClassGenericPassword, kSecClassInternetPassword, kSecClassKey]
        for secClass in classes {
            let query: [String: Any] = [kSecClass as String: secClass, kSecAttrService as String: service]
            SecItemDelete(query as CFDictionary)
        }
    }
}

// MARK: - Well-known keys

extension KeychainService: LockoutStore {}

enum KeychainKey {
    static let passcodeHash = "passcodeHash"
    static let passcodeSalt = "passcodeSalt"
    static let failedAttempts = "failedAttempts"
    static let lockoutUntil = "lockoutUntil"
    static let sessionToken = "sessionToken"
    static let lockoutUptimeDeadline = "lockoutUptimeDeadline"
    static let lockoutBootAnchor = "lockoutBootAnchor"
    static let lockoutDuration = "lockoutDuration"
    static let biometricGate = "biometricGate"
    static let duressPasscodeHash = "duressPasscodeHash"
    static let duressPasscodeSalt = "duressPasscodeSalt"
}
