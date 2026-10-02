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
        if ProcessInfo.processInfo.isiOSAppOnMac {
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !installed else {
            hosting.view.frame = canvas.bounds
            return
        }
        let canvas = canvas
        guard canvas !== view, !view.isDescendant(of: canvas) else {
            attach(hosting.view, to: view)
            installed = true
            return
        }
        canvas.isUserInteractionEnabled = true
        attach(hosting.view, to: canvas)
        addChild(hosting)
        hosting.didMove(toParent: self)
        installed = true
    }

    private var canvas: UIView {
        field.subviews.first ?? field
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
