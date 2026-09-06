import SwiftUI

/// Port of "Transitions.dev — Input clear with dissolve". The original is
/// explicitly JS-per-frame for its glow streak ("the streak's rise/peak/
/// fall envelope cannot be expressed as a static @keyframe"), which isn't
/// something a static SwiftUI transition can reproduce either — so this
/// port keeps the part that *is* keyframe-expressible: the current value
/// flying up + fading + blurring away, and the placeholder crossfading in
/// underneath it, on tapping the clear button. The glow-streak is
/// intentionally left out rather than faked with something that wouldn't
/// resemble the original.
///
/// Usage:
///   DissolvingClearField(text: $searchText, placeholder: "Search")
struct DissolvingClearField: View {
    @Binding var text: String
    var placeholder: String
    var systemImage: String? = "magnifyingglass"

    @State private var dissolvingText: String?
    @State private var dissolveOffset: CGFloat = 0
    @State private var dissolveOpacity: Double = 1
    @State private var dissolveBlur: CGFloat = 0
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .leading) {
                // The value mid-clear, flying up and dissolving away.
                if let dissolvingText {
                    Text(dissolvingText)
                        .foregroundStyle(.primary)
                        .offset(y: dissolveOffset)
                        .opacity(dissolveOpacity)
                        .blur(radius: dissolveBlur)
                        .allowsHitTesting(false)
                }

                TextField(placeholder, text: $text)
                    .focused($isFocused)
                    .opacity(dissolvingText == nil ? 1 : 0)
            }

            if !text.isEmpty {
                Button(action: clear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.bankGroupedBackground, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: text.isEmpty)
    }

    private func clear() {
        guard !text.isEmpty else { return }

        if reduceMotion {
            text = ""
            return
        }

        let outgoing = text
        text = ""
        dissolvingText = outgoing
        dissolveOffset = 0
        dissolveOpacity = 1
        dissolveBlur = 0

        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.4)) {
            dissolveOffset = -12
            dissolveOpacity = 0
            dissolveBlur = 2
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            dissolvingText = nil
        }
    }
}

#Preview {
    StatefulPreviewWrapper()
}

private struct StatefulPreviewWrapper: View {
    @State private var text = "Coffee shop"
    var body: some View {
        DissolvingClearField(text: $text, placeholder: "Search")
            .padding()
    }
}
