import Foundation
import UserNotifications
import Combine

/// Local notifications for transactions, low balance, large payments, and
/// the weekly summary. Demo mode has no push server — these fire on-device.
@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    static let largeTransactionThreshold: Decimal = 50_000
    static let lowBalanceThreshold: Decimal = 1_000

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let weeklyIdentifier = "weekly-summary"

    private init() {
        Task { await refreshStatus() }
    }

    func requestAuthorizationIfNeeded() async {
        await refreshStatus()
        guard authorizationStatus == .notDetermined else { return }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorizationStatus = granted ? .authorized : .denied
        } catch {
            authorizationStatus = .denied
        }
    }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func notifyTransaction(
        amount: Decimal,
        title: String,
        body: String,
        remainingBalance: Decimal? = nil
    ) {
        let settings = AppSettings.shared
        guard settings.isTransactionNotificationsEnabled else {
            maybeNotifyLarge(amount: amount, title: title)
            maybeNotifyLowBalance(remainingBalance)
            return
        }

        schedule(
            identifier: "txn-\(UUID().uuidString)",
            title: title,
            body: body,
            delay: 0.4
        )
        maybeNotifyLarge(amount: amount, title: title)
        maybeNotifyLowBalance(remainingBalance)
    }

    func notifyLogin(decoy: Bool) {
        schedule(
            identifier: "login-\(UUID().uuidString)",
            title: decoy ? "Session started" : "New login",
            body: decoy ? "A limited session is active on this device." : "BankSecure was unlocked on this device.",
            delay: 0.3
        )
    }

    func rescheduleWeeklySummary() {
        center.removePendingNotificationRequests(withIdentifiers: [weeklyIdentifier])
        guard AppSettings.shared.isWeeklySummaryEnabled else { return }

        var components = DateComponents()
        components.weekday = 2
        components.hour = 8
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Weekly spending summary"
        content.body = "Your BankSecure weekly summary is ready. Open Track to review spending."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: weeklyIdentifier, content: content, trigger: trigger))
    }

    private func maybeNotifyLarge(amount: Decimal, title: String) {
        guard AppSettings.shared.isLargeTransactionAlertsEnabled,
              amount >= Self.largeTransactionThreshold else { return }
        schedule(
            identifier: "large-\(UUID().uuidString)",
            title: "Large transaction",
            body: "\(title) for \(CurrencyFormatter.shared.string(from: amount)) exceeded ₹50,000.",
            delay: 1.0
        )
    }

    private func maybeNotifyLowBalance(_ remaining: Decimal?) {
        guard AppSettings.shared.isLowBalanceAlertsEnabled,
              let remaining, remaining < Self.lowBalanceThreshold else { return }
        schedule(
            identifier: "low-\(UUID().uuidString)",
            title: "Low balance",
            body: "Available balance is \(CurrencyFormatter.shared.string(from: remaining)).",
            delay: 1.2
        )
    }

    private func schedule(identifier: String, title: String, body: String, delay: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 0.2), repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
