import SwiftUI

/// An Apple Pay-style "done" moment: a ring draws itself in, a checkmark
/// strokes on afterward, then everything settles with a soft scale-up.
/// Used for UPI payments (and easy to reuse for transfers/bill pay).
struct PaymentSuccessAnimation: View {
    let amount: String
    var subtitle: String = "Payment Complete"
    var onFinished: (() -> Void)? = nil

    @State private var ringTrim: CGFloat = 0
    @State private var checkTrim: CGFloat = 0
    @State private var circleScale: CGFloat = 0.6
    @State private var contentOpacity: Double = 0
    @State private var haloOpacity: Double = 0

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .stroke(Color.bankSuccess.opacity(0.15), lineWidth: 10)
                    .frame(width: 96, height: 96)
                    .scaleEffect(1.4)
                    .opacity(haloOpacity)

                Circle()
                    .trim(from: 0, to: ringTrim)
                    .stroke(Color.bankSuccess, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(-90))

                Checkmark()
                    .trim(from: 0, to: checkTrim)
                    .stroke(Color.bankSuccess, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    .frame(width: 40, height: 32)
            }
            .scaleEffect(circleScale)

            VStack(spacing: 4) {
                Text(amount)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .opacity(contentOpacity)
        }
        .onAppear { animate() }
    }

    private func animate() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            circleScale = 1.0
        }
        withAnimation(.easeInOut(duration: 0.45)) {
            ringTrim = 1.0
        }
        withAnimation(.easeInOut(duration: 0.35).delay(0.4)) {
            checkTrim = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            haloOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.55)) {
            contentOpacity = 1.0
        }
        HapticFeedbackService.shared.success()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            onFinished?()
        }
    }
}

nonisolated private struct Checkmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// The one success overlay: a translucent backdrop with a material card.
///
/// `.payment` presents `PaymentSuccessAnimation` (Apple Pay-style ring draw) and
/// dismisses itself when the animation finishes. `.check` shows a springy checkmark
/// with a title, message and Done button, dismisses on backdrop tap, and
/// auto-dismisses after `dismissAfter`.
struct SuccessOverlay: View {
    enum Style {
        case payment(amount: String, subtitle: String)
        case check(title: String, message: String, dismissAfter: Duration)
    }

    let style: Style
    @Binding var isPresented: Bool
    var onDone: () -> Void = {}
    @State private var checkmarkScale: CGFloat = 0.4

    var body: some View {
        switch style {
        case let .payment(amount, subtitle):
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                PaymentSuccessAnimation(amount: amount, subtitle: subtitle) {
                    dismiss()
                }
                .padding(AppSpacing.xxl)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
                .padding(.horizontal, AppSpacing.xxl)
            }
            .transition(.opacity)
        case let .check(title, message, dismissAfter):
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                        .scaleEffect(checkmarkScale)
                        .onAppear {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                                checkmarkScale = 1.0
                            }
                        }

                    Text(title)
                        .font(.headline)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    ModernButton(title: "Done", systemImage: nil, variant: .filled) {
                        dismiss()
                    }
                    .padding(.top, AppSpacing.sm)
                }
                .padding(AppSpacing.xl)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
                .padding(.horizontal, AppSpacing.xxl)
            }
            .task {
                try? await Task.sleep(for: dismissAfter)
                dismiss()
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
        onDone()
    }
}

struct PaymentSuccessAnimation_Previews: PreviewProvider {
    static var previews: some View {
        PaymentSuccessAnimation(amount: "₹1,250.00")
    }
}
