import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class HapticFeedbackService {
    static let shared = HapticFeedbackService()
    private init() {}

    func errorOccurred() {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        guard !PlatformUI.isMac else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    func success() {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        guard !PlatformUI.isMac else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    func warning() {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        guard !PlatformUI.isMac else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    func lightImpact() {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        guard !PlatformUI.isMac else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
