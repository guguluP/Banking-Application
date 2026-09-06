import SwiftUI

/// Port of "Transitions.dev — Shimmer text". The CSS clips an animated
/// gradient to the text glyphs via `background-clip: text`; SwiftUI's
/// closest equivalent is rendering the same gradient and using the text
/// itself as a `.mask`, then sweeping the gradient's position — same
/// visual result, continuous and JS-free, matching the original's "pure
/// CSS — no JS, no class toggling."
///
/// Usage:
///   ShimmerText("Planning next moves")
/// A natural fit for the AI chatbot's "thinking" state or any
/// in-progress status line.
struct ShimmerText: View {
    let text: String
    var font: Font = .subheadline
    var baseColor: Color = .secondary
    var highlightColor: Color = .primary
    var duration: Double = 2.0

    init(_ text: String,
         font: Font = .subheadline,
         baseColor: Color = .secondary,
         highlightColor: Color = .primary,
         duration: Double = 2.0) {
        self.text = text
        self.font = font
        self.baseColor = baseColor
        self.highlightColor = highlightColor
        self.duration = duration
    }

    @State private var phase: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(baseColor)
            .overlay {
                GeometryReader { geo in
                    let bandWidth = geo.size.width * 4 // mirrors --shimmer-band: 400%
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.4),
                            .init(color: highlightColor, location: 0.5),
                            .init(color: .clear, location: 0.6),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: bandWidth)
                    .offset(x: -bandWidth * phase + geo.size.width)
                }
                .mask(
                    Text(text).font(font)
                )
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 0
                }
            }
    }
}

#Preview {
    ShimmerText("Planning next moves")
        .padding()
}

