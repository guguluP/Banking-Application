import Foundation
import Combine
import SwiftUI

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
        static let appearanceMode = "settings.appearanceMode"
        static let languageIndex = "settings.languageIndex"
        static let regionIndex = "settings.regionIndex"
        static let dateFormat = "settings.dateFormat"
        static let timeFormat = "settings.timeFormat"
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

    /// Light / Dark / follow-System appearance override, applied at the app
    /// root via `.preferredColorScheme`.
    @Published var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: Key.appearanceMode) }
    }

    @Published var languageIndex: Int {
        didSet { UserDefaults.standard.set(languageIndex, forKey: Key.languageIndex) }
    }

    @Published var regionIndex: Int {
        didSet { UserDefaults.standard.set(regionIndex, forKey: Key.regionIndex) }
    }

    @Published var dateFormat: BankDateFormat {
        didSet { UserDefaults.standard.set(dateFormat.rawValue, forKey: Key.dateFormat) }
    }

    @Published var timeFormat: BankTimeFormat {
        didSet { UserDefaults.standard.set(timeFormat.rawValue, forKey: Key.timeFormat) }
    }

    static let languageOptions = ["English (US)", "English (UK)", "Hindi", "Spanish", "French"]
    static let regionOptions = ["India", "United States", "United Kingdom", "Canada", "Australia"]

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

        if let raw = defaults.string(forKey: Key.appearanceMode), let mode = AppearanceMode(rawValue: raw) {
            appearanceMode = mode
        } else {
            appearanceMode = .system
        }

        languageIndex = defaults.integer(forKey: Key.languageIndex)
        regionIndex = defaults.integer(forKey: Key.regionIndex)
        if let raw = defaults.string(forKey: Key.dateFormat), let format = BankDateFormat(rawValue: raw) {
            dateFormat = format
        } else {
            dateFormat = .dayMonthYear
        }
        if let raw = defaults.string(forKey: Key.timeFormat), let format = BankTimeFormat(rawValue: raw) {
            timeFormat = format
        } else {
            timeFormat = .twelveHour
        }
    }

    var languageLabel: String {
        Self.languageOptions.indices.contains(languageIndex) ? Self.languageOptions[languageIndex] : Self.languageOptions[0]
    }

    var regionLabel: String {
        Self.regionOptions.indices.contains(regionIndex) ? Self.regionOptions[regionIndex] : Self.regionOptions[0]
    }
}

/// User-selectable appearance override. `.system` means "no override" —
/// the app follows the device's own light/dark setting.
enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var systemImage: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    /// Maps to the SwiftUI `.preferredColorScheme(_:)` value; `nil` for
    /// `.system` tells SwiftUI to defer to the device setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum BankDateFormat: String, CaseIterable {
    case monthDayYear = "MM/DD/YYYY"
    case dayMonthYear = "DD/MM/YYYY"
    case yearMonthDay = "YYYY/MM/DD"
}

enum BankTimeFormat: String, CaseIterable {
    case twelveHour = "12-Hour"
    case twentyFourHour = "24-Hour"
}
