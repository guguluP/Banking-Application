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

    init(cornerRadius: CGFloat = AppTheme.CornerRadius.large, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
    }
}