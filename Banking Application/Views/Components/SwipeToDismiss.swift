import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Swipe-down dismiss for modal/sheet content. On Mac (pointer / windowed),
/// the gesture is disabled so scroll and trackpad interaction stay natural.
struct SwipeToDismiss: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false

    private let dismissThreshold: CGFloat = 120
    private let velocityThreshold: CGFloat = 600

    func body(content: Content) -> some View {
        if PlatformUI.isMac {
            content
        } else {
            content
                .offset(y: dragOffset)
                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.86), value: dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 8, coordinateSpace: .local)
                        .updating($isDragging) { _, state, _ in state = true }
                        .onChanged { value in
                            guard value.translation.height > 0 else { return }
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            let draggedFarEnough = value.translation.height > dismissThreshold
                            let flickedFastEnough = value.predictedEndTranslation.height > dismissThreshold
                                && value.translation.height > 0
                            let velocity = value.predictedEndLocation.y - value.location.y

                            if draggedFarEnough || flickedFastEnough || velocity > velocityThreshold {
                                KeyboardDismiss.resign()
                                dragOffset = 800
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    dismiss()
                                }
                            } else {
                                dragOffset = 0
                            }
                        }
                )
        }
    }
}

extension View {
    func swipeDownToDismiss() -> some View {
        modifier(SwipeToDismiss())
    }
}
