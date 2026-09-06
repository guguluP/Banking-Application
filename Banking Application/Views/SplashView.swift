import SwiftUI

struct SplashView: View {
    let onDismiss: () -> Void

    @State private var animateLogo = false
    @State private var animateDots = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
                .ignoresSafeArea()

            Color.bankAmbientGradient
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: AppSpacing.xxl) {
                ZStack {
                    Circle()
                        .fill(Color.bankPrimary.opacity(0.12))
                        .frame(width: 140, height: 140)
                        .blur(radius: 2)

                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 72, weight: .medium))
                        .foregroundStyle(Color.bankPrimaryGradient)
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(animateLogo ? 1 : 0.55)
                        .opacity(animateLogo ? 1 : 0)
                        .rotationEffect(.degrees(animateLogo || reduceMotion ? 0 : -120))
                }
                .animation(
                    reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.8, dampingFraction: 0.65),
                    value: animateLogo
                )

                VStack(spacing: 10) {
                    Text("BankSecure")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Your trusted banking companion")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(animateLogo ? 1 : 0)
                .offset(y: animateLogo ? 0 : 16)
                .animation(.easeOut(duration: 0.55).delay(reduceMotion ? 0 : 0.15), value: animateLogo)

                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.bankPrimary)
                            .frame(width: 8, height: 8)
                            .scaleEffect(animateDots ? 1 : 0.5)
                            .opacity(animateDots ? 1 : 0.3)
                            .animation(
                                reduceMotion
                                    ? .easeOut(duration: 0.2)
                                    : .spring(response: 0.5, dampingFraction: 0.6)
                                        .delay(Double(index) * 0.15),
                                value: animateDots
                            )
                    }
                }
                .opacity(animateLogo ? 1 : 0)
            }
            .adaptiveContentWidth(420)
        }
        .onAppear {
            animateLogo = true
            animateDots = true

            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.6 : 1.8)) {
                onDismiss()
            }
        }
    }
}
