import SwiftUI

/// Centralizes Liquid Glass adoption (iOS 26+) so the rest of the app never
/// has to scatter `#available` checks around. Below iOS 26, every helper
/// here falls back to a genuine `Material` — still real translucency and
/// blur, just not the refractive Liquid Glass render — which already looks
/// and behaves far better than a flat, semi-opaque color.
///
/// Design rule this file encodes, straight from Apple's Liquid Glass HIG:
/// glass belongs on the *control* layer — buttons, segmented controls,
/// floating toolbars — not on dense content surfaces like a scrolling
/// transaction list or a balance card. Real glass sampling real glass (or
/// sitting over long-form text) reads as muddy, not premium. Content
/// surfaces use `GlassCard` (see ModernCard.swift), which deliberately uses
/// Material rather than `.glassEffect()` even on iOS 26+, because financial
/// figures need to stay legible first.
enum LiquidGlass {

    /// Wraps a row of adjacent glass controls (e.g. icon buttons) so they
    /// blend and morph together the way Apple's own controls do. Real glass
    /// elements placed side by side *without* a shared container sample
    /// independently and look inconsistent — this is a no-op wrapper below
    /// iOS 26, where that concern doesn't apply.
    @ViewBuilder
    static func container<Content: View>(
        spacing: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

extension View {
    /// The one place in the app that decides "real Liquid Glass, or the
    /// best available fallback." Intended for controls only — buttons,
    /// segmented controls, floating icons — not content cards.
    @ViewBuilder
    func glassControl(
        cornerRadius: CGFloat = AppTheme.CornerRadius.pill,
        tint: Color? = nil,
        interactive: Bool = true
    ) -> some View {
        if #available(iOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let base = tint.map { Glass.regular.tint($0) } ?? .regular
            self.glassEffect(interactive ? base.interactive() : base, in: shape)
        } else {
            self
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
        }
    }
}
