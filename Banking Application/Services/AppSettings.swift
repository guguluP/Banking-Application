import Foundation
import SwiftUI

/// Single source of truth for user-facing preferences that are not credentials.
/// Sensitive values (passcode hash, session token) stay in `KeychainService`.
/// These toggles previously lived only as `@State` on settings screens and
/// did nothing — wiring them here makes Privacy, Profile, Login, and
/// Notifications all read/write the same flags.
@MainActor
@Observable
final class AppSettings {
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
        static let roundUpEnabled = "roundUpEnabled"
        static let dailyTransfer = "limits.dailyTransfer"
        static let monthlyTransfer = "limits.monthlyTransfer"
        static let dailyUPI = "limits.dailyUPI"
        static let monthlyUPI = "limits.monthlyUPI"
        static let dailyBill = "limits.dailyBill"
        static let monthlyBill = "limits.monthlyBill"
        static let largeAmount = "limits.largeAmount"
        static let coolingHours = "limits.coolingHours"
        static let coolingLarge = "limits.coolingLarge"
    }

    var isBiometricsEnabled: Bool {
        didSet { UserDefaults.standard.set(isBiometricsEnabled, forKey: Key.biometricsEnabled) }
    }

    var isPasscodeLockEnabled: Bool {
        didSet { UserDefaults.standard.set(isPasscodeLockEnabled, forKey: Key.passcodeLockEnabled) }
    }

    var isTransactionNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(isTransactionNotificationsEnabled, forKey: Key.transactionNotifications) }
    }

    var isMarketingNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(isMarketingNotificationsEnabled, forKey: Key.marketingNotifications) }
    }

    var isLowBalanceAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(isLowBalanceAlertsEnabled, forKey: Key.lowBalanceAlerts) }
    }

    var isLargeTransactionAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(isLargeTransactionAlertsEnabled, forKey: Key.largeTransactionAlerts) }
    }

    var isWeeklySummaryEnabled: Bool {
        didSet { UserDefaults.standard.set(isWeeklySummaryEnabled, forKey: Key.weeklySummary) }
    }

    /// When true, balances show as •••• on home and account cards.
    var hideBalances: Bool {
        didSet { UserDefaults.standard.set(hideBalances, forKey: Key.hideBalances) }
    }

    /// Light / Dark / follow-System appearance override, applied at the app
    /// root via `.preferredColorScheme`.
    var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: Key.appearanceMode) }
    }

    var languageIndex: Int {
        didSet { UserDefaults.standard.set(languageIndex, forKey: Key.languageIndex) }
    }

    var regionIndex: Int {
        didSet { UserDefaults.standard.set(regionIndex, forKey: Key.regionIndex) }
    }

    var dateFormat: BankDateFormat {
        didSet { UserDefaults.standard.set(dateFormat.rawValue, forKey: Key.dateFormat) }
    }

    var timeFormat: BankTimeFormat {
        didSet { UserDefaults.standard.set(timeFormat.rawValue, forKey: Key.timeFormat) }
    }

    var isRoundUpEnabled: Bool {
        didSet { UserDefaults.standard.set(isRoundUpEnabled, forKey: Key.roundUpEnabled) }
    }

    var dailyTransferLimit: Decimal
    var monthlyTransferLimit: Decimal
    var dailyUPILimit: Decimal
    var monthlyUPILimit: Decimal
    var dailyBillPayLimit: Decimal
    var monthlyBillPayLimit: Decimal
    var largeTransactionAmount: Decimal
    var payeeCoolingHours: Double
    var coolingLargeAmount: Decimal

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

        isRoundUpEnabled = defaults.bool(forKey: Key.roundUpEnabled)
        dailyTransferLimit = Self.decimal(defaults, Key.dailyTransfer, 50_000)
        monthlyTransferLimit = Self.decimal(defaults, Key.monthlyTransfer, 200_000)
        dailyUPILimit = Self.decimal(defaults, Key.dailyUPI, 100_000)
        monthlyUPILimit = Self.decimal(defaults, Key.monthlyUPI, 200_000)
        dailyBillPayLimit = Self.decimal(defaults, Key.dailyBill, 100_000)
        monthlyBillPayLimit = Self.decimal(defaults, Key.monthlyBill, 200_000)
        largeTransactionAmount = Self.decimal(defaults, Key.largeAmount, 10_000)
        payeeCoolingHours = defaults.object(forKey: Key.coolingHours) == nil ? 24 : defaults.double(forKey: Key.coolingHours)
        coolingLargeAmount = Self.decimal(defaults, Key.coolingLarge, 5_000)
    }

    func persistLimits() {
        let defaults = UserDefaults.standard
        func store(_ value: Decimal, _ key: String) {
            defaults.set(NSDecimalNumber(decimal: value).stringValue, forKey: key)
        }
        store(dailyTransferLimit, Key.dailyTransfer)
        store(monthlyTransferLimit, Key.monthlyTransfer)
        store(dailyUPILimit, Key.dailyUPI)
        store(monthlyUPILimit, Key.monthlyUPI)
        store(dailyBillPayLimit, Key.dailyBill)
        store(monthlyBillPayLimit, Key.monthlyBill)
        store(largeTransactionAmount, Key.largeAmount)
        store(coolingLargeAmount, Key.coolingLarge)
        defaults.set(payeeCoolingHours, forKey: Key.coolingHours)
    }

    private static func decimal(_ defaults: UserDefaults, _ key: String, _ fallback: Decimal) -> Decimal {
        guard let raw = defaults.string(forKey: key), let value = Decimal(string: raw) else { return fallback }
        return value
    }

    var languageLabel: String {
        Self.languageOptions.indices.contains(languageIndex) ? Self.languageOptions[languageIndex] : Self.languageOptions[0]
    }

    var regionLabel: String {
        Self.regionOptions.indices.contains(regionIndex) ? Self.regionOptions[regionIndex] : Self.regionOptions[0]
    }

    /// Date only, using the saved order. Locale is pinned so the device region cannot reorder it.
    func formattedDate(_ date: Date) -> String {
        dateFormatter(dateFormat.pattern).string(from: date)
    }

    func formattedTime(_ date: Date) -> String {
        dateFormatter(timeFormat.pattern).string(from: date)
    }

    /// Date and time together, using the saved date order and 12/24-hour choice.
    func formattedDateTime(_ date: Date) -> String {
        dateFormatter("\(dateFormat.pattern) \(timeFormat.pattern)").string(from: date)
    }

    /// One formatter per pattern. There are only a handful of date/time patterns, and
    /// creating a `DateFormatter` per row was the expensive part of rendering a list.
    private static var formatterCache: [String: DateFormatter] = [:]

    private func dateFormatter(_ pattern: String) -> DateFormatter {
        if let cached = Self.formatterCache[pattern] { return cached }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = pattern
        Self.formatterCache[pattern] = formatter
        return formatter
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

    var pattern: String {
        switch self {
        case .monthDayYear: return "MM/dd/yyyy"
        case .dayMonthYear: return "dd/MM/yyyy"
        case .yearMonthDay: return "yyyy/MM/dd"
        }
    }
}

enum BankTimeFormat: String, CaseIterable {
    case twelveHour = "12-Hour"
    case twentyFourHour = "24-Hour"

    var pattern: String {
        switch self {
        case .twelveHour: return "h:mm a"
        case .twentyFourHour: return "HH:mm"
        }
    }
}
