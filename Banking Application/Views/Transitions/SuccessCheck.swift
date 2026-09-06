import SwiftUI

/// Port of "Transitions.dev — Success check". A lighter-weight confirmation
/// than `PaymentSuccessAnimation` (which owns the full ring-draw Apple-Pay
/// moment for payments) — this is for smaller "saved" / "added" / "copied"
/// moments: a checkmark that fades in while rotating from 80°, unblurring,
/// and bobbing up into place, with its stroke drawing on in parallel.
///
/// Usage:
///   SuccessCheckView(isShown: viewModel.didSave)
struct SuccessCheckView: View {
    var isShown: Bool
    var size: CGFloat = 48
    var tint: Color = .bankSuccess

    @State private var opacity: Double = 0
    @State private var rotation: Angle = .degrees(80)
    @State private var blurRadius: CGFloat = 10
    @State private var yOffset: CGFloat = 40
    @State private var trim: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Checkmark()
            .trim(from: 0, to: trim)
            .stroke(tint, style: StrokeStyle(lineWidth: max(3, size / 12), lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size * 0.8)
            .opacity(opacity)
            .rotationEffect(rotation)
            .blur(radius: blurRadius)
            .offset(y: yOffset)
            .onAppear { if isShown { animateIn() } }
            .onChange(of: isShown) { _, newValue in
                if newValue { animateIn() } else { reset() }
            }
    }

    private func animateIn() {
        if reduceMotion {
            opacity = 1
            rotation = .zero
            blurRadius = 0
            yOffset = 0
            trim = 1
            return
        }

        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.5)) {
            opacity = 1
            rotation = .zero
            blurRadius = 0
        }
        withAnimation(.timingCurve(0.34, 1.35, 0.64, 1, duration: 0.5)) {
            yOffset = 0
        }
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.5).delay(0.08)) {
            trim = 1
        }
    }

    private func reset() {
        opacity = 0
        rotation = .degrees(80)
        blurRadius = 10
        yOffset = 40
        trim = 0
    }
}

/// A simple checkmark path, reused from the same construction as
/// `PaymentSuccessAnimation`'s `Checkmark` shape so the two draw
/// identically when both appear in the app.
nonisolated private struct Checkmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

#Preview {
    StatefulPreviewWrapper()
}

private struct StatefulPreviewWrapper: View {
    @State private var isShown = false
    var body: some View {
        VStack(spacing: 24) {
            SuccessCheckView(isShown: isShown)
            Button("Toggle") { isShown.toggle() }
        }
        .padding()
    }
}
