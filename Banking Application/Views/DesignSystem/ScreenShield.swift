import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Puts sensitive content inside a secure-text-field canvas so the system
/// snapshot used for screenshots and the app switcher captures a blank field.
/// Also covers the screen while `UIScreen.isCaptured` is true.
struct ScreenShield: ViewModifier {
    @State private var captured = false

    func body(content: Content) -> some View {
        content
            #if canImport(UIKit) && os(iOS)
            .background(SecureFieldHost())
            .overlay {
                if captured {
                    Color.black.ignoresSafeArea()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                captured = UIScreen.main.isCaptured
            }
            .onAppear { captured = UIScreen.main.isCaptured }
            #endif
    }
}

#if canImport(UIKit) && os(iOS)
/// Inserts a secure text field behind the SwiftUI content and reparents the
/// hosting layer into that field's canvas. The field itself does not intercept taps.
private struct SecureFieldHost: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.isUserInteractionEnabled = false
        let field = UITextField()
        field.isSecureTextEntry = true
        field.isUserInteractionEnabled = false
        container.addSubview(field)
        DispatchQueue.main.async {
            guard let canvas = field.subviews.first else { return }
            canvas.isUserInteractionEnabled = false
            guard let host = container.superview else { return }
            canvas.removeFromSuperview()
            host.addSubview(canvas)
            canvas.frame = host.bounds
            canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            // Move existing siblings into the secure canvas so the snapshot blanks them.
            for child in host.subviews where child !== canvas {
                canvas.addSubview(child)
            }
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif

extension View {
    func sensitiveScreenShield() -> some View {
        modifier(ScreenShield())
    }
}
