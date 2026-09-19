import SwiftUI

/// Liquid Glass for controls and floating chrome.
///
/// iOS 27 keeps the same `glassEffect` / `GlassEffectContainer` APIs and
/// automatically honors the system Appearance → Liquid Glass slider
/// (ultraclear → fully tinted). Dense money surfaces stay on `GlassCard`
/// (opaque-enough fill) so figures stay readable and we do not stack a
/// refractive sample on every row.
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

    /// iOS 27 prefers `.clear` when the user has slid the system control
    /// toward ultraclear; `.regular` remains the readable default.
    static func style(tint: Color? = nil) -> Glass {
        var glass: Glass = .regular
        if let tint {
            glass = glass.tint(tint)
        }
        return glass
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
            let base = LiquidGlass.style(tint: tint)
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

    @ViewBuilder
    func glassCircle(tint: Color? = nil, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            let base = LiquidGlass.style(tint: tint)
            self.glassEffect(interactive ? base.interactive() : base, in: Circle())
        } else {
            self.glassControl(cornerRadius: 999, tint: tint, interactive: interactive)
        }
    }
}
