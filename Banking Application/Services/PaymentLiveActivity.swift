import Foundation
import SwiftUI
import Combine
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Shared attributes for the payment Live Activity (Lock Screen / Dynamic Island).
/// Marked `nonisolated` because this app target defaults new types to
/// `@MainActor` isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), but
/// `ActivityKit` calls into `ActivityAttributes` conformances (e.g. from
/// `Activity.end`) off the main actor — a main-actor-isolated conformance
/// can't satisfy that, hence the explicit opt-out here.
nonisolated struct PaymentActivityAttributes: Codable, Hashable, Sendable {
    var paymentKind: String
    var counterparty: String
}

#if canImport(ActivityKit)
extension PaymentActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        var status: String
        var amountText: String
        var isComplete: Bool
    }
}
#endif

/// Starts/updates/ends ActivityKit live activities when available, and always
/// drives an in-app banner so Mac / iOS-on-Mac still show progress.
@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    struct Banner: Equatable {
        var title: String
        var subtitle: String
        var isComplete: Bool
    }

    @Published var banner: Banner?

#if canImport(ActivityKit)
    private var activity: Activity<PaymentActivityAttributes>?
#endif

    func startPayment(kind: String, counterparty: String, amount: Decimal) {
        let amountText = CurrencyFormatter.shared.string(from: amount)
        banner = Banner(title: "\(kind) in progress", subtitle: "\(amountText) · \(counterparty)", isComplete: false)

#if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = PaymentActivityAttributes(paymentKind: kind, counterparty: counterparty)
        let state = PaymentActivityAttributes.ContentState(
            status: "Processing",
            amountText: amountText,
            isComplete: false
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: Date().addingTimeInterval(120))
            )
        } catch {
            // Live Activities are unavailable on Mac / iOS-on-Mac; banner still shows.
        }
#endif
    }

    func completePayment() {
        banner = Banner(
            title: banner?.title.replacingOccurrences(of: "in progress", with: "sent") ?? "Payment sent",
            subtitle: banner?.subtitle ?? "Completed",
            isComplete: true
        )
        // End the Live Activity asynchronously; this type is @MainActor so no need to hop explicitly.
        Task { @MainActor [weak self] in
            await self?.endActivity(status: "Completed")
        }
        // After a short delay, clear the in-app banner on the main actor.
        Task { @Sendable [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            await MainActor.run {
                if self?.banner?.isComplete == true {
                    self?.banner = nil
                }
            }
        }
    }

    func failPayment() {
        banner = nil
        Task { @MainActor [weak self] in
            await self?.endActivity(status: "Failed")
        }
    }

    @MainActor private func endActivity(status: String) async {
#if canImport(ActivityKit)
        guard let currentActivity = self.activity else { return }
        let amountText = currentActivity.content.state.amountText
        self.activity = nil

        let state = PaymentActivityAttributes.ContentState(
            status: status,
            amountText: amountText,
            isComplete: true
        )
        let content = ActivityContent(state: state, staleDate: nil)

        // `Activity<T>.end` is `@concurrent` in recent SDKs, so passing a
        // main-actor-fetched `Activity` into it trips the sending-parameter
        // check even though `Activity` is a thread-safe reference type
        // ActivityKit itself hands across actors. Safe to opt out here.
        nonisolated(unsafe) let activityToEnd = currentActivity
        await activityToEnd.end(content, dismissalPolicy: .after(.now + 4))
#endif
    }
}

struct InAppLiveActivityBanner: View {
    @ObservedObject private var manager = LiveActivityManager.shared

    var body: some View {
        VStack {
            if let banner = manager.banner {
                HStack(spacing: 10) {
                    Image(systemName: banner.isComplete ? "checkmark.circle.fill" : "arrow.left.arrow.right.circle.fill")
                        .foregroundStyle(banner.isComplete ? Color.bankSuccess : Color.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(banner.title)
                            .font(.caption.weight(.semibold))
                        Text(banner.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.88), in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: manager.banner)
        .allowsHitTesting(false)
    }
}

