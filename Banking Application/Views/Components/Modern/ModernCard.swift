import SwiftUI

struct ModernCard<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    let cornerRadius: CGFloat

    init(
        backgroundColor: Color = .bankCardBackground,
        cornerRadius: CGFloat = AppTheme.CornerRadius.medium,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .bankCardShadow()
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    /// When true, the card uses a single Liquid Glass surface (hero only).
    /// Default cards use a cheap translucent fill so a dashboard of many
    /// cards does not sample glass/material on every frame.
    var reactsToTilt: Bool = false
    var tint: Color? = nil

    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = AppTheme.CornerRadius.card,
        reactsToTilt: Bool = false,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.reactsToTilt = reactsToTilt
        self.tint = tint
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let card = content
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.22 : 0.55),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .bankCardShadow()

        if reactsToTilt {
            card.glassControl(cornerRadius: cornerRadius, tint: tint, interactive: false)
        } else {
            card
                .background {
                    ZStack {
                        shape.fill(fillColor)
                        if let tint {
                            shape.fill(tint.opacity(0.07))
                        }
                    }
                }
        }
    }

    private var fillColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.78)
    }
}
