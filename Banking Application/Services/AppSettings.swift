import Foundation
import Combine

/// Single source of truth for user-facing preferences that are not credentials.
/// Sensitive values (passcode hash, session token) stay in `KeychainService`.
/// These toggles previously lived only as `@State` on settings screens and
/// did nothing — wiring them here makes Privacy, Profile, Login, and
/// Notifications all read/write the same flags.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let biometricsEnabled = "settings.biometricsEnabled"
        static let passcodeLockEnabled = "settings.passcodeLockEnabled"
        static let transactionNotifications = "settings.transactionNotifications"
        static let marketingNotifications = "settings.marketingNotifications"
        static let lowBalanceAlerts = "settings.lowBalanceAlerts"
        static let largeTransactionAlerts = "settings.largeTransactionAlerts"
        static let weeklySummary = "settings.weeklySummary"
        static let hideBalances = "settings.hideBalances"
        /// Legacy key used by ProfileView before this service existed.
        static let legacyUseBiometrics = "useBiometrics"
    }

    @Published var isBiometricsEnabled: Bool {
        didSet { UserDefaults.standard.set(isBiometricsEnabled, forKey: Key.biometricsEnabled) }
    }

    @Published var isPasscodeLockEnabled: Bool {
        didSet { UserDefaults.standard.set(isPasscodeLockEnabled, forKey: Key.passcodeLockEnabled) }
    }

    @Published var isTransactionNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(isTransactionNotificationsEnabled, forKey: Key.transactionNotifications) }
    }

    @Published var isMarketingNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(isMarketingNotificationsEnabled, forKey: Key.marketingNotifications) }
    }

    @Published var isLowBalanceAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(isLowBalanceAlertsEnabled, forKey: Key.lowBalanceAlerts) }
    }

    @Published var isLargeTransactionAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(isLargeTransactionAlertsEnabled, forKey: Key.largeTransactionAlerts) }
    }

    @Published var isWeeklySummaryEnabled: Bool {
        didSet { UserDefaults.standard.set(isWeeklySummaryEnabled, forKey: Key.weeklySummary) }
    }

    /// When true, balances show as •••• on home and account cards.
    @Published var hideBalances: Bool {
        didSet { UserDefaults.standard.set(hideBalances, forKey: Key.hideBalances) }
    }

    private init() {
        let defaults = UserDefaults.standard

        // Prefer the new key; fall back to the older ProfileView key once.
        if defaults.object(forKey: Key.biometricsEnabled) != nil {
            isBiometricsEnabled = defaults.bool(forKey: Key.biometricsEnabled)
        } else if defaults.object(forKey: Key.legacyUseBiometrics) != nil {
            isBiometricsEnabled = defaults.bool(forKey: Key.legacyUseBiometrics)
        } else {
            isBiometricsEnabled = true
        }

        isPasscodeLockEnabled = defaults.object(forKey: Key.passcodeLockEnabled) == nil
            ? true
            : defaults.bool(forKey: Key.passcodeLockEnabled)

        isTransactionNotificationsEnabled = defaults.object(forKey: Key.transactionNotifications) == nil
            ? true
            : defaults.bool(forKey: Key.transactionNotifications)

        isMarketingNotificationsEnabled = defaults.bool(forKey: Key.marketingNotifications)
        isLowBalanceAlertsEnabled = defaults.object(forKey: Key.lowBalanceAlerts) == nil
            ? true
            : defaults.bool(forKey: Key.lowBalanceAlerts)
        isLargeTransactionAlertsEnabled = defaults.object(forKey: Key.largeTransactionAlerts) == nil
            ? true
            : defaults.bool(forKey: Key.largeTransactionAlerts)
        isWeeklySummaryEnabled = defaults.bool(forKey: Key.weeklySummary)
        hideBalances = defaults.bool(forKey: Key.hideBalances)
    }
}
