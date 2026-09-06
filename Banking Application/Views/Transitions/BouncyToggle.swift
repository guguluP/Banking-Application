import SwiftUI

/// Port of "Transitions.dev — Toggle". A drop-in replacement for
/// SwiftUI's plain `Toggle` when you want the thumb to travel with the
/// CSS original's double-bounce (overshoot past the end, swing back,
/// settle) rather than a single ease. Track color still cross-fades on
/// its own clock, same division of labor as `.t-toggle`'s `transition:
/// background`.
///
/// Usage:
///   BouncyToggle(isOn: $notificationsEnabled)
///
/// The CSS's `.is-init` (added on first interaction so the "off"
/// keyframes don't play on load) is handled internally: the very first
/// render never animates, matching "cold load looks correct with no
/// animation," and every toggle after that replays the bounce.
struct BouncyToggle: View {
    @Binding var isOn: Bool

    var onTint: Color = .bankPrimary
    var offTint: Color = Color.bankSeparator
    var travel: CGFloat = 20
    var duration: Double = 0.35
    /// --toggle-ov1 / --toggle-ov2 from the CSS: first overshoot past the
    /// end, then a smaller correction on the way back before settling.
    var overshoot1: CGFloat = 2.5
    var overshoot2: CGFloat = 1

    @State private var hasInteracted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let thumbDiameter: CGFloat = 24
    private let trackHeight: CGFloat = 28

    var body: some View {
        Button {
            HapticFeedbackService.shared.lightImpact()
            hasInteracted = true
            isOn.toggle()
        } label: {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isOn ? onTint : offTint)
                    .animation(.easeInOut(duration: 0.15), value: isOn)

                thumb
                    .padding(2)
            }
            .frame(width: trackHeight + travel, height: trackHeight)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isOn ? "On" : "Off")
    }

    @ViewBuilder
    private var thumb: some View {
        let resting = Circle()
            .fill(.white)
            .frame(width: thumbDiameter, height: thumbDiameter)
            .shadow(color: .black.opacity(0.15), radius: 1.5, x: 0, y: 1)
            .offset(x: isOn ? travel : 0)

        if reduceMotion || !hasInteracted {
            // Matches the CSS's cold-load behavior: the thumb sits at its
            // resting `translate` with no keyframes played.
            resting
        } else {
            Circle()
                .fill(.white)
                .frame(width: thumbDiameter, height: thumbDiameter)
                .shadow(color: .black.opacity(0.15), radius: 1.5, x: 0, y: 1)
                .keyframeAnimator(initialValue: isOn ? 0 : travel, trigger: isOn) { view, x in
                    view.offset(x: x)
                } keyframes: { _ in
                    if isOn {
                        CubicKeyframe(travel + overshoot1, duration: duration * 0.55)
                        CubicKeyframe(travel - overshoot2, duration: duration * 0.25)
                        CubicKeyframe(travel, duration: duration * 0.20)
                    } else {
                        CubicKeyframe(-overshoot1, duration: duration * 0.55)
                        CubicKeyframe(overshoot2, duration: duration * 0.25)
                        CubicKeyframe(0, duration: duration * 0.20)
                    }
                }
        }
    }
}

#Preview {
    StatefulPreviewWrapper()
}

private struct StatefulPreviewWrapper: View {
    @State private var isOn = false
    var body: some View {
        BouncyToggle(isOn: $isOn).padding()
    }
}

/// Lets the same double-bounce animation drop into any existing
/// `Toggle(isOn:) { label }` call site via `.toggleStyle(.bouncy)`,
/// without changing how those call sites are written — `BouncyToggle`
/// itself is a standalone control for places with no separate label.
struct BouncyToggleStyle: ToggleStyle {
    var onTint: Color = .bankPrimary
    var offTint: Color = Color.bankSeparator

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            BouncyToggle(isOn: configuration.$isOn, onTint: onTint, offTint: offTint)
        }
    }
}

extension ToggleStyle where Self == BouncyToggleStyle {
    static var bouncy: BouncyToggleStyle { BouncyToggleStyle() }
}
