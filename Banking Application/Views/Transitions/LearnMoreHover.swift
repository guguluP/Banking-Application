import SwiftUI

/// Port of "Transitions.dev — Learn more hover". On pointer platforms
/// (trackpad/mouse via `PlatformUI.usesPointerInput`), hovering shifts the
/// chevron right and its two arms rotate apart about the apex, exactly as
/// the CSS's `transform-origin: 10px 8px` + opposite rotations describe.
/// On touch-only iOS there's no hover state to drive this from, so the
/// chevron simply renders at rest — the same graceful no-op the CSS's
/// `@media (prefers-reduced-motion: reduce)` block performs.
struct LearnMoreButton: View {
    let title: String
    let action: () -> Void

    var shift: CGFloat = 2
    var spread: Angle = .degrees(8)

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                LearnMoreChevron(isSpread: isHovering && !reduceMotion, shift: shift, spread: spread)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            guard PlatformUI.usesPointerInput else { return }
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.35)) {
                isHovering = hovering
            }
        }
    }
}

/// The chevron itself: two paths meeting at an apex, each rotating in
/// opposite directions around that apex so the angle visibly "opens."
private struct LearnMoreChevron: View {
    var isSpread: Bool
    var shift: CGFloat
    var spread: Angle

    var body: some View {
        ZStack {
            ChevronArm(top: true)
                .stroke(Color.bankPrimary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(isSpread ? spread : .zero, anchor: UnitPoint(x: 10.0 / 14.0, y: 8.0 / 14.0))
            ChevronArm(top: false)
                .stroke(Color.bankPrimary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(isSpread ? -spread : .zero, anchor: UnitPoint(x: 10.0 / 14.0, y: 8.0 / 14.0))
        }
        .frame(width: 14, height: 14)
        .offset(x: isSpread ? shift : 0)
    }
}

/// Reproduces the two SVG path arms from the CSS example
/// (`M6 4L10 8` and `M10 8L6 12`) in a 14x14 box to match the frame above.
private nonisolated struct ChevronArm: Shape {
    let top: Bool

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        if top {
            path.move(to: CGPoint(x: rect.minX + 6, y: rect.minY + 4))
            path.addLine(to: CGPoint(x: rect.minX + 10, y: rect.minY + 8))
        } else {
            path.move(to: CGPoint(x: rect.minX + 10, y: rect.minY + 8))
            path.addLine(to: CGPoint(x: rect.minX + 6, y: rect.minY + 12))
        }
        return path
    }
}

#Preview {
    LearnMoreButton(title: "Learn more") {}
        .padding()
}
