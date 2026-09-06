import SwiftUI

/// Port of "Transitions.dev — Texts reveal". Each line starts translated
/// down + blurred + invisible; `isShown` flips them to rest with a
/// per-line stagger delay (line *N* delayed by `stagger * (N-1)`, same as
/// `.t-stagger-line--2 { transition-delay: var(--stagger-stagger) }` and
/// onward). Hiding uses a fast, un-staggered plain fade — no Y return, no
/// blur — matching the CSS's explicit decoupling: "the disappearance
/// reads as a single quiet fade instead of a reverse reveal."
///
/// Usage:
///   StaggeredTextReveal(isShown: showIntro) {
///       Text("Welcome to BankSecure").font(.title2.bold())
///       Text("Track spending, transfer money, and more.")
///   }
struct StaggeredTextReveal<Content: View>: View {
    var isShown: Bool
    var stagger: Double = 0.04
    var duration: Double = 0.5
    var distance: CGFloat = 12
    var blurRadius: CGFloat = 3
    @ViewBuilder var content: () -> Content

    var body: some View {
        _VariadicView.Tree(StaggeredLineLayout(isShown: isShown, stagger: stagger, duration: duration, distance: distance, blurRadius: blurRadius)) {
            content()
        }
    }
}

private struct StaggeredLineLayout: _VariadicView_UnaryViewRoot {
    let isShown: Bool
    let stagger: Double
    let duration: Double
    let distance: CGFloat
    let blurRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                child
                    .opacity(isShown || reduceMotion ? 1 : 0)
                    .offset(y: isShown || reduceMotion ? 0 : distance)
                    .blur(radius: isShown || reduceMotion ? 0 : blurRadius)
                    .animation(
                        reduceMotion ? nil : (
                            isShown
                                ? .timingCurve(0.22, 1, 0.36, 1, duration: duration).delay(Double(index) * stagger)
                                // Hide: fast, un-staggered, opacity-only —
                                // matches `.is-hiding`'s 200ms plain fade.
                                : .easeOut(duration: 0.2)
                        ),
                        value: isShown
                    )
            }
        }
    }
}

#Preview {
    StatefulPreviewWrapper()
}

private struct StatefulPreviewWrapper: View {
    @State private var isShown = false
    var body: some View {
        VStack(spacing: 24) {
            StaggeredTextReveal(isShown: isShown) {
                Text("Welcome to BankSecure").font(.title2.bold())
                Text("Track spending, transfer money, and more.")
                    .foregroundStyle(.secondary)
            }
            Button("Toggle") { isShown.toggle() }
        }
        .padding()
    }
}
