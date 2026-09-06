import SwiftUI

extension Color {
    /// Trust-forward banking blue — slightly deeper for better contrast on glass.
    static let bankPrimary = Color(red: 0.12, green: 0.42, blue: 0.92)
    /// Fresh growth green for credits / success accents.
    static let bankSecondary = Color(red: 0.18, green: 0.72, blue: 0.48)
    /// Warm amber for CTAs and attention without alarm.
    static let bankAccent = Color(red: 1.0, green: 0.55, blue: 0.12)
    static let bankSuccess = Color(red: 0.20, green: 0.78, blue: 0.45)
    static let bankWarning = Color(red: 0.98, green: 0.72, blue: 0.10)
    static let bankDanger = Color(red: 0.94, green: 0.28, blue: 0.28)

    /// Soft violet used in AI / insight chrome.
    static let bankInsight = Color(red: 0.48, green: 0.38, blue: 0.96)
}

extension ShapeStyle where Self == Color {
    static var bankPrimary: Color { Color.bankPrimary }
    static var bankSecondary: Color { Color.bankSecondary }
    static var bankAccent: Color { Color.bankAccent }
    static var bankSuccess: Color { Color.bankSuccess }
    static var bankWarning: Color { Color.bankWarning }
    static var bankDanger: Color { Color.bankDanger }
    static var bankInsight: Color { Color.bankInsight }
}
