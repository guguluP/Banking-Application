import Combine
import SwiftUI

/// One entry in the stack — mirrors `.t-stack-banner`'s content slot.
/// `id` drives SwiftUI identity; `depth` (0 = newest/frontmost) is
/// recomputed by `BannerStackManager` exactly like the CSS comment
/// describes: "step every older banner's data-depth one back."
struct BannerItem: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var message: String
    var icon: String = "bell.fill"
    var tint: Color = .bankPrimary
}

/// Port of "Transitions.dev — Banner stacking". Manages up to three
/// visible depths (0, 1, 2) the way the CSS's `[data-depth]` selectors do;
/// a fourth banner gets pushed straight to a leaving state instead of a
/// fourth depth tier, matching "a fourth banner gets .is-leaving."
///
/// Usage:
///   @StateObject var stack = BannerStackManager()
///   ...
///   BannerStackView(manager: stack)
///   ...
///   stack.push(BannerItem(title: "Payment sent", message: "₹500 to Rahul"))
@MainActor
final class BannerStackManager: ObservableObject {
    /// App-wide instance. Mounted once via `BannerStackView(manager: .shared)`
    /// near the root of the visible hierarchy (see `AccountOverviewView`) so
    /// any screen can call `BannerStackManager.shared.push(...)` — e.g. after
    /// a transfer, UPI payment, or bill pay completes — without needing to
    /// thread a binding through every intermediate view.
    static let shared = BannerStackManager()

    @Published fileprivate(set) var items: [BannerItem] = []
    @Published var isSpread = false

    private var dismissWorkItems: [UUID: DispatchWorkItem] = [:]
    private let maxVisibleDepth = 2
    private let autoDismissDelay: Double

    init(autoDismissDelay: Double = 3.5) {
        self.autoDismissDelay = autoDismissDelay
    }

    /// Inserts a new banner at depth 0, pushing every existing one back a
    /// depth. Anything that would land past `maxVisibleDepth` is dropped
    /// immediately rather than animated through a leave — the CSS keeps a
    /// max of 3 resting depths (0/1/2) plus one transient `.is-leaving`
    /// slot, and this mirrors that ceiling.
    func push(_ item: BannerItem) {
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.35)) {
            items.insert(item, at: 0)
            if items.count > maxVisibleDepth + 1 {
                items.removeLast(items.count - (maxVisibleDepth + 1))
            }
        }
        scheduleAutoDismiss(for: item.id)
    }

    func dismiss(_ item: BannerItem) {
        dismissWorkItems[item.id]?.cancel()
        dismissWorkItems[item.id] = nil
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.25)) {
            items.removeAll { $0.id == item.id }
        }
    }

    /// Touch equivalent of the CSS's pointer-in-stack-box hover spread —
    /// there's no hover on iOS, so a tap-and-hold or a plain tap toggles
    /// the spread instead.
    func toggleSpread() {
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.35)) {
            isSpread.toggle()
        }
    }

    private func scheduleAutoDismiss(for id: UUID) {
        dismissWorkItems[id]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let item = self.items.first(where: { $0.id == id }) else { return }
            self.dismiss(item)
        }
        dismissWorkItems[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDelay, execute: work)
    }
}

/// Renders the manager's `items` as a depth-stacked pile of cards. Place
/// this near the bottom of a screen (e.g. in a `ZStack` overlay) the way
/// `.t-stack` sits as a fixed toast container.
struct BannerStackView: View {
    @ObservedObject var manager: BannerStackManager

    private let peek: CGFloat = 12
    private let depthScale: CGFloat = 0.06
    private let depthFade: Double = 0.4
    private let spreadGap: CGFloat = 8
    private let bannerHeight: CGFloat = 64

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(Array(manager.items.enumerated()), id: \.element.id) { index, item in
                bannerCard(for: item)
                    .zIndex(Double(manager.items.count - index))
                    .offset(y: offsetY(forDepth: index))
                    .scaleEffect(scale(forDepth: index), anchor: .bottom)
                    .opacity(opacity(forDepth: index))
                    .allowsHitTesting(index == 0 || manager.isSpread)
            }
        }
        .frame(height: bannerHeight)
        .onTapGesture {
            if manager.items.count > 1 {
                manager.toggleSpread()
            }
        }
    }

    private func bannerCard(for item: BannerItem) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: item.icon)
                .foregroundStyle(item.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline.weight(.semibold))
                Text(item.message).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .frame(height: bannerHeight)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
        .transition(
            .asymmetric(
                insertion: .offset(y: 80).combined(with: .opacity),
                removal: .offset(y: -peek * 3).combined(with: .opacity)
            )
        )
    }

    private func offsetY(forDepth depth: Int) -> CGFloat {
        guard depth > 0 else { return 0 }
        if manager.isSpread {
            return -(CGFloat(depth) * (bannerHeight + spreadGap))
        }
        return -(peek * CGFloat(depth))
    }

    private func scale(forDepth depth: Int) -> CGFloat {
        guard depth > 0 else { return 1 }
        if manager.isSpread { return 1 }
        return 1 - (depthScale * CGFloat(depth))
    }

    private func opacity(forDepth depth: Int) -> Double {
        guard depth > 0 else { return 1 }
        if manager.isSpread { return 1 }
        return 1 - min(depthFade * Double(depth) * 1.0, 0.95)
    }
}

#Preview {
    PreviewWrapper()
}

private struct PreviewWrapper: View {
    @StateObject private var stack = BannerStackManager()
    var body: some View {
        VStack {
            Spacer()
            Button("Push banner") {
                stack.push(BannerItem(title: "Payment sent", message: "₹500 to Rahul", icon: "checkmark.circle.fill", tint: .bankSuccess))
            }
            BannerStackView(manager: stack)
        }
    }
}

