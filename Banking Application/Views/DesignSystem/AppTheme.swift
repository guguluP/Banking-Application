import SwiftUI

struct AppTheme {
    struct Colors {
        static let primary = Color.bankPrimary
        static let secondary = Color.bankSecondary
        static let accent = Color.bankAccent
        static let success = Color.bankSuccess
        static let warning = Color.bankWarning
        static let danger = Color.bankDanger
    }
    
    struct Typography {
        static func largeTitle() -> Font { .largeTitle.weight(.bold) }
        static func title() -> Font { .title.weight(.bold) }
        static func title2() -> Font { .title2.weight(.semibold) }
        static func headline() -> Font { .headline.weight(.semibold) }
    }
    
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 20
        static let pill: CGFloat = 24
    }
}