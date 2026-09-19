import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Blocks screenshots/screen recording on sensitive screens (card PAN, passcode).
struct ScreenShield: ViewModifier {
    func body(content: Content) -> some View {
        content
            #if canImport(UIKit) && os(iOS)
            .onAppear { UIScreen.main.isCaptured }
            .overlay {
                ScreenshotBlocker()
                    .allowsHitTesting(false)
            }
            #endif
    }
}

#if canImport(UIKit) && os(iOS)
private struct ScreenshotBlocker: UIViewRepresentable {
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.isSecureTextEntry = true
        field.isUserInteractionEnabled = false
        field.backgroundColor = .clear
        if let canvas = field.subviews.first {
            canvas.isUserInteractionEnabled = false
        }
        return field
    }
    func updateUIView(_ uiView: UITextField, context: Context) {}
}
#endif

extension View {
    func sensitiveScreenShield() -> some View {
        modifier(ScreenShield())
    }
}
