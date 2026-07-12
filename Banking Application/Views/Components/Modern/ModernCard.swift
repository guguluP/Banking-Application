import SwiftUI

struct ModernCard<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    let cornerRadius: CGFloat
    
    init(backgroundColor: Color = Color(UIColor.systemBackground), cornerRadius: CGFloat = AppTheme.CornerRadius.medium, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    /// When true, the border highlight subtly brightens on the edge facing
    /// the tilt direction — like light glancing off glass. Off by default
    /// since `GlassCard` is used dozens of times per screen; only enable
    /// it on a handful of hero cards (e.g. the home balance card) to avoid
    /// running CoreMotion for every card that scrolls on/off screen.
    var reactsToTilt: Bool = false

    @ObservedObject private var motion = MotionManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        cornerRadius: CGFloat = AppTheme.CornerRadius.large,
        reactsToTilt: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.reactsToTilt = reactsToTilt
    }

    private var tiltActive: Bool { reactsToTilt && !reduceMotion }

    var body: some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(strokeTopOpacity), Color.white.opacity(0.05)],
                            startPoint: tiltActive ? highlightStart : .topLeading,
                            endPoint: tiltActive ? highlightEnd : .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .animation(.easeOut(duration: 0.15), value: motion.normalizedX)
            )
            .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
            .onAppear { if tiltActive { MotionManager.shared.subscribe() } }
            .onDisappear { if tiltActive { MotionManager.shared.unsubscribe() } }
    }

    private var strokeTopOpacity: Double {
        tiltActive ? 0.55 + abs(motion.normalizedX) * 0.25 : 0.55
    }

    private var highlightStart: UnitPoint {
        UnitPoint(x: 0.5 + motion.normalizedX * 0.4, y: 0.5 + motion.normalizedY * 0.4 - 0.5)
    }

    private var highlightEnd: UnitPoint {
        UnitPoint(x: 0.5 - motion.normalizedX * 0.4, y: 0.5 - motion.normalizedY * 0.4 + 0.5)
    }
}