import SwiftUI

extension Color {
    static let bankPrimary = Color(red: 0.13, green: 0.47, blue: 0.95)
    static let bankSecondary = Color(red: 0.35, green: 0.78, blue: 0.52)
    static let bankAccent = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let bankSuccess = Color(red: 0.32, green: 0.82, blue: 0.41)
    static let bankWarning = Color(red: 1.0, green: 0.76, blue: 0.12)
    static let bankDanger = Color(red: 1.0, green: 0.32, blue: 0.27)
    
    static let glassBackground = Color(uiColor: UIColor.systemBackground).opacity(0.7)
    static let glassBorder = Color.white.opacity(0.2)
}

extension ShapeStyle where Self == Color {
    static var bankPrimary: Color { Color.bankPrimary }
    static var bankSecondary: Color { Color.bankSecondary }
    static var bankAccent: Color { Color.bankAccent }
    static var bankSuccess: Color { Color.bankSuccess }
    static var bankWarning: Color { Color.bankWarning }
    static var bankDanger: Color { Color.bankDanger }
}