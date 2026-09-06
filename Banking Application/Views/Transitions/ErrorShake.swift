import SwiftUI

/// Port of "Transitions.dev — Error state shake". Wrap any field/wrapper
/// in `.errorShake(isError:)` to get the same four-segment shake
/// (right → left → small overshoot → settle) the CSS keyframe defines,
/// plus a border-color state and an error message that fades in
/// immediately and auto-reverts after a hold period — matching the
/// `--revert-hold` / `--revert-dur` behavior from the original.
///
/// Usage:
///   ModernTextField(...)
///     .errorShake(isError: viewModel.showEmailError)
///
/// Unlike the CSS version (which needs the caller to manually restart
/// `.is-shaking` by removing/reflowing/re-adding the class), this
/// modifier watches `isError` itself and replays the shake any time it
/// flips from `false` to `true` — including repeated failures in a row,
/// via an internal trigger counter.
struct ErrorShakeModifier: ViewModifier {
    var isError: Bool
    var shakeDistance: CGFloat = 6
    var shakeOvershoot: CGFloat = 4
    /// --shake-dur-a / --shake-dur-b from the CSS: two leg durations that,
    /// doubled, sum to the total keyframe duration (280ms by default).
    var durationA: Double = 0.08
    var durationB: Double = 0.06

    @State private var shakeTrigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .modifier(ShakeKeyframeModifier(
                trigger: shakeTrigger,
                distance: shakeDistance,
                overshoot: shakeOvershoot,
                durationA: durationA,
                durationB: durationB,
                reduceMotion: reduceMotion
            ))
            .onChange(of: isError) { _, newValue in
                if newValue {
                    shakeTrigger += 1
                }
            }
    }
}

/// The actual shake, isolated into its own `KeyframeAnimator`-backed
/// modifier so `trigger` can drive replays independently of `isError`'s
/// steady-state value (a `KeyframeAnimator` re-runs whenever its
/// `trigger` value changes, which is exactly the "remove + reflow +
/// re-add is-shaking" restart the CSS comment describes).
private struct ShakeKeyframeModifier: ViewModifier {
    var trigger: Int
    var distance: CGFloat
    var overshoot: CGFloat
    var durationA: Double
    var durationB: Double
    var reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: CGFloat(0), trigger: trigger) { view, offset in
                view.offset(x: offset)
            } keyframes: { _ in
                // Cumulative %-stops from the CSS (28.57/57.14/78.57/100 of
                // durationA*2 + durationB*2) translate directly to
                // consecutive keyframe durations here, since each
                // `CubicKeyframe` duration is relative, not cumulative.
                CubicKeyframe(distance, duration: durationA)
                CubicKeyframe(-distance, duration: durationA)
                CubicKeyframe(overshoot, duration: durationB)
                CubicKeyframe(0, duration: durationB)
            }
        }
    }
}

/// The border-color + message half of the effect — a small companion view
/// mirroring `.t-error-msg`'s asymmetric fade (instant appear, delayed
/// disappear so text stays fully painted through its own fade-out) and
/// the auto-revert timer from `--revert-hold`.
struct ErrorRevertMessage: View {
    let message: String
    var isError: Bool
    var revertHold: Double = 3.0
    var revertDuration: Double = 0.28
    /// Called when the hold timer elapses and the caller should clear
    /// its own error state — mirrors the CSS comment's instruction to
    /// "drop both `.is-error` classes" after the hold.
    var onRevert: (() -> Void)? = nil

    @State private var isVisible = false
    @State private var revertWorkItem: DispatchWorkItem?

    var body: some View {
        Text(message)
            .font(.caption2)
            .foregroundStyle(Color.bankDanger)
            .opacity(isVisible ? 1 : 0)
            .animation(.easeOut(duration: revertDuration), value: isVisible)
            .onChange(of: isError) { _, newValue in
                revertWorkItem?.cancel()
                if newValue {
                    isVisible = true
                    let work = DispatchWorkItem {
                        isVisible = false
                        onRevert?()
                    }
                    revertWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + revertHold, execute: work)
                } else {
                    isVisible = false
                }
            }
            .onAppear { isVisible = isError }
    }
}

extension View {
    /// Applies the four-segment error shake whenever `isError` transitions
    /// to `true`. Border-color response is left to the field itself
    /// (`ModernTextField` already recolors its border on `isValid`), same
    /// division of responsibility as the original CSS: "this stylesheet
    /// only owns the tween."
    func errorShake(isError: Bool, distance: CGFloat = 6, overshoot: CGFloat = 4) -> some View {
        modifier(ErrorShakeModifier(isError: isError, shakeDistance: distance, shakeOvershoot: overshoot))
    }
}
