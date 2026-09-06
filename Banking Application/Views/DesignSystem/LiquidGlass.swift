import SwiftUI

/// Centralizes Liquid Glass adoption (iOS 26+ / macOS 26+) so the rest of the
/// app never has to scatter `#available` checks around. Below that OS, every
/// helper falls back to a genuine `Material` — real translucency and blur,
/// just not the refractive Liquid Glass render.
///
/// Glass belongs on the *control* layer — buttons, segmented controls,
/// floating toolbars — not dense content surfaces. Content uses `GlassCard`
/// (Material) so financial figures stay legible.
enum LiquidGlass {

    @ViewBuilder
    static func container<Content: View>(
        spacing: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

extension View {
    @ViewBuilder
    func glassControl(
        cornerRadius: CGFloat = AppTheme.CornerRadius.pill,
        tint: Color? = nil,
        interactive: Bool = true
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let base = tint.map { Glass.regular.tint($0) } ?? .regular
            self.glassEffect(interactive ? base.interactive() : base, in: shape)
        } else {
            self
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                        if let tint {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(tint.opacity(0.18))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.45),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: AppShadows.small.color, radius: AppShadows.small.radius, x: 0, y: 1)
        }
    }
}
