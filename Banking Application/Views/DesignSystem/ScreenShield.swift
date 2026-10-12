import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Hides sensitive screens from screenshots by placing that screen's content
/// inside a secure text field. It does not move existing layers around, which
/// is what produced "layer is a part of cycle in its layer tree".
/// On a Mac running the iOS app, that field hierarchy is skipped. Screen
/// recording is still covered with a black overlay.
struct ScreenShield<Content: View>: View {
    let content: Content
    @State private var captured = false

    var body: some View {
        #if canImport(UIKit) && os(iOS)
        shielded
            .overlay {
                if captured {
                    Color.black.ignoresSafeArea()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                captured = UIScreen.main.isCaptured
            }
            .onAppear { captured = UIScreen.main.isCaptured }
        #else
        content
        #endif
    }

    #if canImport(UIKit) && os(iOS)
    @ViewBuilder
    private var shielded: some View {
        // Mac Catalyst and iOS-on-Mac do not have the iPhone secure canvas.
        // Putting the login into that field sizes it to a text line and shifts it.
        if PlatformUI.isMac {
            content
        } else {
            SecureContentHost(content: content)
        }
    }
    #endif
}

#if canImport(UIKit) && os(iOS)
private struct SecureContentHost<Content: View>: UIViewControllerRepresentable {
    let content: Content

    func makeUIViewController(context: Context) -> ShieldController<Content> {
        ShieldController(root: content)
    }

    func updateUIViewController(_ controller: ShieldController<Content>, context: Context) {
        controller.hosting.rootView = content
    }
}

private final class ShieldController<Content: View>: UIViewController {
    let hosting: UIHostingController<Content>
    private let field = UITextField()
    private var installed = false
    private var installAttempts = 0
    private var attachedParent: UIView?

    init(root: Content) {
        hosting = UIHostingController(rootView: root)
        super.init(nibName: nil, bundle: nil)
        hosting.view.backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        field.isSecureTextEntry = true
        field.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            field.topAnchor.constraint(equalTo: view.topAnchor),
            field.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// UIKit inserts the private secure canvas after the field is on screen.
    /// Stay uninstalled until `field.subviews.first` is that canvas, not the
    /// field itself, and retry on later layouts. After a few misses, show the
    /// hosting view on this controller unshielded instead of a blank screen.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if installed {
            hosting.view.frame = (attachedParent ?? view).bounds
            return
        }
        // A zero-sized pass is not an attempt; the canvas appears once the field has bounds.
        guard !field.bounds.isEmpty else { return }

        installAttempts += 1
        if let canvas = secureCanvas, canvas !== view, !view.isDescendant(of: canvas) {
            install(on: canvas, shielded: true)
            return
        }
        if installAttempts >= 5 {
            install(on: view, shielded: false)
        }
    }

    /// The secure canvas UIKit adds inside the field. Nil until that subview exists.
    private var secureCanvas: UIView? {
        guard let canvas = field.subviews.first, canvas !== field else { return nil }
        return canvas
    }

    private func install(on parent: UIView, shielded: Bool) {
        if shielded {
            parent.isUserInteractionEnabled = true
        }
        attachedParent = parent
        installed = true
        attach(hosting.view, to: parent)
        if hosting.parent == nil {
            addChild(hosting)
            hosting.didMove(toParent: self)
        }
    }

    private func attach(_ child: UIView, to parent: UIView) {
        child.translatesAutoresizingMaskIntoConstraints = true
        child.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        child.frame = parent.bounds
        parent.addSubview(child)
    }
}
#endif

extension View {
    func sensitiveScreenShield() -> some View {
        ScreenShield(content: self)
    }
}
