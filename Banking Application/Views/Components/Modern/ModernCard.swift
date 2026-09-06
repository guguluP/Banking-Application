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
    /// When true, the border highlight subtly brightens on the edge facing
    /// the tilt direction. Off by default; enable on hero cards only.
    var reactsToTilt: Bool = false
    /// Optional soft brand tint under the material.
    var tint: Color? = nil

    @ObservedObject private var motion = MotionManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    private var tiltActive: Bool { reactsToTilt && !reduceMotion && !PlatformUI.isMac }

    var body: some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    if let tint {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(0.08))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(strokeTopOpacity),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: tiltActive ? highlightStart : .topLeading,
                            endPoint: tiltActive ? highlightEnd : .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .animation(.easeOut(duration: 0.15), value: motion.normalizedX)
            )
            .bankCardShadow()
            .onAppear { if tiltActive { MotionManager.shared.subscribe() } }
            .onDisappear { if tiltActive { MotionManager.shared.unsubscribe() } }
    }

    private var strokeTopOpacity: Double {
        tiltActive ? 0.55 + abs(motion.normalizedX) * 0.25 : 0.5
    }

    private var highlightStart: UnitPoint {
        UnitPoint(x: 0.5 + motion.normalizedX * 0.4, y: 0.5 + motion.normalizedY * 0.4 - 0.5)
    }

    private var highlightEnd: UnitPoint {
        UnitPoint(x: 0.5 - motion.normalizedX * 0.4, y: 0.5 - motion.normalizedY * 0.4 + 0.5)
    }
}
