import SwiftUI

struct AppShadows {
    static let card = (color: Color.black.opacity(0.07), radius: CGFloat(14), x: CGFloat(0), y: CGFloat(6))
    static let small = (color: Color.black.opacity(0.04), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(1))
    static let medium = (color: Color.black.opacity(0.09), radius: CGFloat(10), x: CGFloat(0), y: CGFloat(3))
    static let large = (color: Color.black.opacity(0.14), radius: CGFloat(20), x: CGFloat(0), y: CGFloat(8))
    static let glow = (color: Color.bankPrimary.opacity(0.22), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(4))
}

extension View {
    func bankCardShadow() -> some View {
        shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
    }

    func bankGlowShadow() -> some View {
        shadow(color: AppShadows.glow.color, radius: AppShadows.glow.radius, x: AppShadows.glow.x, y: AppShadows.glow.y)
    }
}
