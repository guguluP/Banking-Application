import SwiftUI
import UIKit

/// A reusable modifier that lets a modal/sheet view be dismissed by swiping down,
/// replacing the old explicit close ("x") buttons used throughout the app.
///
/// Usage:
/// ```
/// NavigationStack {
///     ...
/// }
/// .swipeDownToDismiss()
/// ```
struct SwipeToDismiss: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false

    /// Minimum downward drag (in points) required to trigger dismissal.
    private let dismissThreshold: CGFloat = 120
    /// Minimum downward velocity (points/sec) that also triggers dismissal, even
    /// if the drag distance threshold wasn't reached (a quick flick down).
    private let velocityThreshold: CGFloat = 600

    func body(content: Content) -> some View {
        content
            .offset(y: dragOffset)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.86), value: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .local)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        // Only track downward drags; ignore upward motion so scrolling
                        // content inside the sheet isn't affected.
                        guard value.translation.height > 0 else { return }
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        let draggedFarEnough = value.translation.height > dismissThreshold
                        let flickedFastEnough = value.predictedEndTranslation.height > dismissThreshold
                            && value.translation.height > 0
                        let velocity = value.predictedEndLocation.y - value.location.y

                        if draggedFarEnough || flickedFastEnough || velocity > velocityThreshold {
                            // Close the keyboard (and with it, any active spell-
                            // correction popover) before tearing down the view.
                            // Dismissing while a correction popover is still
                            // attached to a focused text field is what triggers
                            // an AppKit NSCorrectionSubPanel assertion crash
                            // when this iPhone-idiom app runs on Mac.
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

extension View {
    /// Enables swipe-down-to-dismiss on a modal/sheet view. Intended to replace
    /// explicit close (x) buttons in toolbars.
    func swipeDownToDismiss() -> some View {
        modifier(SwipeToDismiss())
    }
}
