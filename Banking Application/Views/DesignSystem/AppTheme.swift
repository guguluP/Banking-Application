import SwiftUI

struct AppTheme {
    struct Typography {
        static func monospacedAmount() -> Font { .title2.weight(.bold).monospacedDigit() }
        static func monospacedHero() -> Font { .largeTitle.weight(.bold).monospacedDigit() }
    }

    struct CornerRadius {
        static let xs: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let large: CGFloat = 18
        static let xl: CGFloat = 22
        static let pill: CGFloat = 28
        static let card: CGFloat = 18
    }

    struct Control {
        static let minTapTarget: CGFloat = 44
        static let buttonHeight: CGFloat = 50
        static let iconButton: CGFloat = 48
        static let keypadButton: CGFloat = 72
    }

    struct Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.18)
        static let standard = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.86)
        static let gentle = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.88)
        static let entrance = SwiftUI.Animation.spring(response: 0.45, dampingFraction: 0.84)
    }
}
