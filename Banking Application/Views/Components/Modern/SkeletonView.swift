import SwiftUI

struct SkeletonView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
            .fill(Color.secondary.opacity(0.2))
            .modifier(ShimmerModifier(phase: phase))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever()) {
                    phase = 1
                }
            }
    }
}

struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonView()
                .frame(height: 16)
            SkeletonView()
                .frame(height: 24)
            SkeletonView()
                .frame(height: 16)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(AppTheme.CornerRadius.medium)
        .shadow(color: AppShadows.small.color, radius: AppShadows.small.radius, x: AppShadows.small.x, y: AppShadows.small.y)
    }
}

struct ShimmerModifier: ViewModifier {
    let phase: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, Color.white.opacity(0.3), .clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: -geometry.size.width + (geometry.size.width * phase))
                        .blendMode(.overlay)
                }
            )
    }
}