import Foundation
import Combine
import LocalAuthentication
import SwiftUI
import SwiftData

/// Handles sign-in for the app: passcode setup/verification and biometrics.
///
/// Security model:
///  - The passcode is **never stored**. Only `SHA256(passcode + perInstallSalt)`
///    is persisted, in the Keychain (`KeychainService`), not `UserDefaults`.
///  - Comparison uses a constant-time check to avoid leaking timing information.
///  - After 5 consecutive failed attempts the account is locked out with an
///    exponentially increasing cooldown, mitigating brute-force PIN guessing.
///  - A successful login mints a random session token stored in the Keychain
///    with `.whenUnlockedThisDeviceOnly`, so it never leaves the device and is
///    wiped on logout.
@MainActor
class AuthenticationService: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLocked: Bool = false {
        didSet {
            if isLocked {
                stopInactivityMonitor()
            }
        }
    }
    @Published var isAuthenticating: Bool = false
    @Published var errorMessage: String?
    @Published var user: User?
    @Published var canUseBiometrics: Bool = false
    @Published var biometryTypeString: String = ""
    @Published var lockoutRemainingSeconds: Int = 0

    /// Whether the user has opted in to biometric unlock in Settings.
    /// Device capability is still gated by `canUseBiometrics`.
    var isBiometricsLoginEnabled: Bool {
        AppSettings.shared.isBiometricsEnabled && canUseBiometrics
    }

    private let keychain = KeychainService.shared
    private let maxFailedAttempts = 5
    private var lockoutTimer: Timer?

    /// How long the app can sit idle in the foreground, unlocked, before it
    /// re-locks itself. Locking on backgrounding alone isn't enough — a
    /// phone left open and unattended on a desk never backgrounds at all,
    /// and RBI's guidance on digital banking apps expects a session
    /// timeout on inactivity as a separate control.
    static let inactivityTimeout: TimeInterval = 90
    private var lastActiveAt = Date()
    private var inactivityTimer: Timer?

    var hasPasscodeConfigured: Bool {
        keychain.getString(forKey: KeychainKey.passcodeHash) != nil
    }

    init() {
        checkBiometricsAvailability()
        refreshLockoutState()
    }

    private func checkBiometricsAvailability() {
        // A fresh, throwaway context for the capability probe only — this is
        // never reused for an actual evaluation.
        let probeContext = LAContext()
        var error: NSError?
        let canEvaluate = probeContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        if canEvaluate {
            canUseBiometrics = true
            switch probeContext.biometryType {
            case .faceID:
                biometryTypeString = "Face ID"
            case .touchID:
                biometryTypeString = "Touch ID"
            case .opticID:
                biometryTypeString = "Optic ID"
            default:
                biometryTypeString = "Biometrics"
            }
        } else {
            canUseBiometrics = false
            biometryTypeString = "Passcode"
        }
    }

    // MARK: - Passcode setup (first run / change passcode)

    /// Creates or overwrites the app passcode with a fresh salt + hash. Used
    /// during onboarding and from `ChangePasscodeView` after the current
    /// passcode has already been verified.
    @discardableResult
    func setPasscode(_ passcode: String) -> Bool {
        guard passcode.count == 4, passcode.allSatisfy({ $0.isNumber }) else { return false }
        let salt = CryptoService.generateSalt()
        let hash = CryptoService.hash(passcode: passcode, salt: salt)
        let saltStored = keychain.set(salt, forKey: KeychainKey.passcodeSalt)
        let hashStored = keychain.set(hash, forKey: KeychainKey.passcodeHash)
        resetFailedAttempts()
        return saltStored && hashStored
    }

    /// Verifies a candidate passcode against the stored hash without revealing
    /// timing information. Does not itself grant a session — call `login`.
    func verifyPasscode(_ passcode: String) -> Bool {
        guard let salt = keychain.getString(forKey: KeychainKey.passcodeSalt),
              let storedHash = keychain.getString(forKey: KeychainKey.passcodeHash) else {
            return false
        }
        let candidateHash = CryptoService.hash(passcode: passcode, salt: salt)
        return CryptoService.constantTimeEquals(candidateHash, storedHash)
    }

    // MARK: - Lockout handling

    private func refreshLockoutState() {
        guard let lockoutUntilRaw = keychain.getString(forKey: KeychainKey.lockoutUntil),
              let lockoutUntil = TimeInterval(lockoutUntilRaw) else {
            lockoutRemainingSeconds = 0
            return
        }
        let remaining = Int(lockoutUntil - Date().timeIntervalSince1970)
        lockoutRemainingSeconds = max(0, remaining)
        if lockoutRemainingSeconds > 0 {
            startLockoutCountdown()
        }
    }

    private func startLockoutCountdown() {
        lockoutTimer?.invalidate()
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.lockoutRemainingSeconds > 0 {
                    self.lockoutRemainingSeconds -= 1
                } else {
                    self.lockoutTimer?.invalidate()
                }
            }
        }
    }

    private func registerFailedAttempt() {
        let attempts = (keychain.getInt(forKey: KeychainKey.failedAttempts) ?? 0) + 1
        keychain.set(attempts, forKey: KeychainKey.failedAttempts)

        guard attempts >= maxFailedAttempts else { return }

        // Exponential backoff beyond the threshold: 30s, 60s, 120s, ...
        let extraStrikes = attempts - maxFailedAttempts
        let cooldown = min(30 * (1 << extraStrikes), 15 * 60)
        let unlockAt = Date().timeIntervalSince1970 + Double(cooldown)
        keychain.set(String(unlockAt), forKey: KeychainKey.lockoutUntil)
        lockoutRemainingSeconds = cooldown
        startLockoutCountdown()
    }

    private func resetFailedAttempts() {
        keychain.delete(forKey: KeychainKey.failedAttempts)
        keychain.delete(forKey: KeychainKey.lockoutUntil)
        lockoutRemainingSeconds = 0
        lockoutTimer?.invalidate()
    }

    // MARK: - Biometrics

    func authenticateWithBiometrics(completion: @escaping @MainActor (Bool) -> Void) {
        guard isBiometricsLoginEnabled, lockoutRemainingSeconds == 0 else {
            if !AppSettings.shared.isBiometricsEnabled {
                errorMessage = "Biometric unlock is turned off in Privacy & Security."
            }
            completion(false)
            return
        }

        // A brand-new LAContext per attempt. Reusing one context across
        // multiple evaluatePolicy calls is what caused Face ID/Touch ID to
        // work only intermittently — once a context has been evaluated (or
        // invalidated by the system, e.g. after backgrounding), further
        // calls on it are unreliable.
        let attemptContext = LAContext()
        isAuthenticating = true
        attemptContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Sign in to BankSecure") { [weak self] success, error in
            Task { @MainActor in
                self?.isAuthenticating = false
                if success {
                    self?.completeAuthentication()
                } else {
                    self?.errorMessage = error?.localizedDescription ?? "Authentication failed"
                }
                completion(success)
            }
        }
    }

    func authenticateWithPasscode(completion: @escaping @MainActor (Bool) -> Void) {
        guard lockoutRemainingSeconds == 0 else {
            completion(false)
            return
        }

        // Same reasoning as above: always a fresh context per attempt.
        let attemptContext = LAContext()
        isAuthenticating = true
        attemptContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Enter your device passcode") { [weak self] success, error in
            Task { @MainActor in
                self?.isAuthenticating = false
                if success {
                    self?.completeAuthentication()
                } else {
                    self?.errorMessage = error?.localizedDescription ?? "Authentication failed"
                }
                completion(success)
            }
        }
    }

    private func completeAuthentication() {
        isAuthenticated = true
        isLocked = false
        errorMessage = nil
        resetFailedAttempts()
        let token = UUID().uuidString
        keychain.set(token, forKey: KeychainKey.sessionToken)
        recordActivity()
        startInactivityMonitor()
    }

    // MARK: - App passcode login

    func login(passcode: String) {
        guard lockoutRemainingSeconds == 0 else {
            errorMessage = "Too many attempts. Try again in \(lockoutRemainingSeconds)s."
            return
        }

        guard passcode.count == 4, passcode.allSatisfy({ $0.isNumber }) else {
            errorMessage = "Please enter your 4-digit passcode"
            return
        }

        guard hasPasscodeConfigured else {
            errorMessage = "No passcode is set up on this device yet."
            return
        }

        isAuthenticating = true

        // A short, deliberate delay avoids the UI flashing instantly on every
        // attempt and gives the same perceived latency for correct/incorrect
        // passcodes, which further reduces timing side-channels.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.isAuthenticating = false

            if self.verifyPasscode(passcode) {
                self.completeAuthentication()
            } else {
                self.registerFailedAttempt()
                let remaining = self.maxFailedAttempts - (self.keychain.getInt(forKey: KeychainKey.failedAttempts) ?? 0)
                if self.lockoutRemainingSeconds > 0 {
                    self.errorMessage = "Too many attempts. Try again in \(self.lockoutRemainingSeconds)s."
                } else if remaining > 0 {
                    self.errorMessage = "Incorrect passcode. \(remaining) attempt(s) remaining."
                } else {
                    self.errorMessage = "Incorrect passcode."
                }
            }
        }
    }

    func logout() {
        isAuthenticated = false
        isLocked = false
        user = nil
        errorMessage = nil
        keychain.delete(forKey: KeychainKey.sessionToken)
        stopInactivityMonitor()
    }

    /// Views call this on any user interaction (see MainTabView's root
    /// gesture) to reset the idle clock. Deliberately cheap — just a
    /// timestamp write — since it runs on every tap and scroll.
    func recordActivity() {
        lastActiveAt = Date()
    }

    func startInactivityMonitor() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isAuthenticated, !self.isLocked else { return }
                if Date().timeIntervalSince(self.lastActiveAt) >= Self.inactivityTimeout {
                    self.isLocked = true
                }
            }
        }
    }

    func stopInactivityMonitor() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }

    /// Loads the signed-in user's profile from the local SwiftData store
    /// (kept in sync with CloudKit) once a session has been established.
    func loadUser(from container: ModelContainer, userId: String = "user_001") {
        let context = container.mainContext
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
        if let existing = try? context.fetch(descriptor).first {
            user = existing
        } else {
            let newUser = User(
                id: userId,
                firstName: "John",
                lastName: "Doe",
                email: "john.doe@example.com",
                phoneNumber: "+91 98765 43210",
                dateOfBirth: Date(timeIntervalSince1970: 631152000),
                address: Address(
                    street: "123 Main St",
                    city: "Bhubaneswar",
                    state: "OD",
                    postalCode: "751001",
                    country: "India"
                )
            )
            context.insert(newUser)
            try? context.save()
            user = newUser
        }
    }
}
