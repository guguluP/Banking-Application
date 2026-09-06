import SwiftUI

/// Port of "Transitions.dev — Text states swap". Reproduces the
/// three-phase sequence from the CSS comment natively:
///   1. Old text slides up + blurs + fades (`.is-exit`).
///   2. Content changes while parked below, unblurred-in (`.is-enter-start`,
///      `transition: none`).
///   3. New text animates back to rest.
///
/// Usage:
///   TextStateSwapView(text: viewModel.statusText)
/// Just changing `text` triggers the whole sequence — no manual class
/// juggling needed, unlike the CSS version which needs the three steps
/// driven by hand.
struct TextStateSwapView: View {
    var text: String
    var font: Font = .subheadline
    var color: Color = .primary

    var duration: Double = 0.15
    var translateY: CGFloat = 4
    var blurRadius: CGFloat = 2

    @State private var displayedText: String
    @State private var phase: Phase = .resting
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase {
        case resting, exit, enterStart
    }

    init(text: String, font: Font = .subheadline, color: Color = .primary, duration: Double = 0.15, translateY: CGFloat = 4, blurRadius: CGFloat = 2) {
        self.text = text
        self.font = font
        self.color = color
        self.duration = duration
        self.translateY = translateY
        self.blurRadius = blurRadius
        _displayedText = State(initialValue: text)
    }

    var body: some View {
        Text(displayedText)
            .font(font)
            .foregroundStyle(color)
            .offset(y: phase == .exit ? -translateY : (phase == .enterStart ? translateY : 0))
            .blur(radius: phase == .resting ? 0 : blurRadius)
            .opacity(phase == .resting ? 1 : 0)
            .animation(phase == .enterStart ? nil : .easeInOut(duration: duration), value: phase)
            .onChange(of: text) { _, newValue in
                guard newValue != displayedText else { return }
                if reduceMotion {
                    displayedText = newValue
                    return
                }
                runSwap(to: newValue)
            }
    }

    private func runSwap(to newValue: String) {
        phase = .exit
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            displayedText = newValue
            phase = .enterStart
            // Force-reflow equivalent: let SwiftUI commit the
            // no-transition "parked below" state on its own render pass
            // before the next phase requests the animated one.
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: duration)) {
                    phase = .resting
                }
            }
        }
    }
}

#Preview {
    StatefulPreviewWrapper()
}

private struct StatefulPreviewWrapper: View {
    @State private var text = "Processing…"
    var body: some View {
        VStack(spacing: 24) {
            TextStateSwapView(text: text)
            Button("Change") { text = text == "Processing…" ? "Complete" : "Processing…" }
        }
        .padding()
    }
}
