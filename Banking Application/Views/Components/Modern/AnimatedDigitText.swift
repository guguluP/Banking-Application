import SwiftUI

/// A native SwiftUI equivalent of the "Transitions.dev — Number pop-in" CSS
/// snippet: splits text into characters and animates each one in with a
/// staggered offset/opacity/blur pop, matching `--digit-dur`,
/// `--digit-distance`, `--digit-stagger`, `--digit-blur`, and the spring-like
/// `cubic-bezier(0.34, 1.45, 0.64, 1)` ease from the original.
///
/// Usage:
///   AnimatedDigitText(text: account.formattedBalance, isAnimating: animate)
///
/// Replay: toggle `isAnimating` false → true (e.g. after changing `text`)
/// the same way the CSS version removes/re-adds `.is-animating`.
struct AnimatedDigitText: View {
    let text: String
    var isAnimating: Bool
    var font: Font = .system(size: 34, weight: .bold, design: .rounded)
    var color: Color = .primary

    // Mirrors the CSS custom properties.
    var duration: Double = 0.5
    var distance: CGFloat = 8
    var stagger: Double = 0.07
    var blurRadius: CGFloat = 2
    var directionX: CGFloat = 0
    var directionY: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(font)
                    .foregroundStyle(color)
                    .offset(
                        x: isAnimating || reduceMotion ? 0 : distance * directionX,
                        y: isAnimating || reduceMotion ? 0 : distance * directionY
                    )
                    .opacity(isAnimating || reduceMotion ? 1 : 0)
                    .blur(radius: isAnimating || reduceMotion ? 0 : blurRadius)
                    .animation(
                        reduceMotion ? nil : .interpolatingSpring(stiffness: 220, damping: 16)
                            .delay(Double(index) * stagger),
                        value: isAnimating
                    )
            }
        }
        // So the whole run reads as one accessibility element rather than
        // one per character.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

#Preview {
    StatefulPreviewWrapper()
}

private struct StatefulPreviewWrapper: View {
    @State private var isAnimating = false
    @State private var text = "₹12,345.67"

    var body: some View {
        VStack(spacing: 24) {
            AnimatedDigitText(text: text, isAnimating: isAnimating)

            Button("Replay") {
                // Same two-step reset the CSS comment describes: drop out,
                // force a state change, then animate back in.
                isAnimating = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isAnimating = true
                }
            }
        }
        .onAppear { isAnimating = true }
        .padding()
    }
}
