import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentStep = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    
    private let onboardingSteps = [
        OnboardingStep(
            image: "creditcard.fill",
            title: "Bank Securely",
            description: "Your trusted companion for all banking needs. View accounts, transfer money, and pay bills."
        ),
        OnboardingStep(
            image: "faceid",
            title: "Biometric Security",
            description: "Secure your transactions with Face ID or Touch ID authentication."
        ),
        OnboardingStep(
            image: "qrcode.viewfinder",
            title: "Instant UPI Payments",
            description: "Pay anyone instantly using UPI. Scan QR codes or enter UPI IDs."
        ),
        OnboardingStep(
            image: "shield.checkered",
            title: "Privacy First",
            description: "Your financial data is encrypted and secure. We never share your information."
        )
    ]
    
    var body: some View {
        ZStack {
            AnimatedMeshBackground()
                .ignoresSafeArea()

            VStack {
                TabView(selection: $currentStep) {
                    ForEach(0..<onboardingSteps.count, id: \.self) { index in
                        OnboardingStepView(step: onboardingSteps[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))

                ModernButton(
                    title: currentStep == onboardingSteps.count - 1 ? "Get Started" : "Next",
                    systemImage: currentStep == onboardingSteps.count - 1 ? "arrow.right.circle.fill" : nil,
                    variant: .filled
                ) {
                    completeOnboarding()
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
                .adaptiveContentWidth(420)
            }
            .onAppear {
                withAnimation(AppTheme.Animation.gentle) {
                    logoScale = 1
                    logoOpacity = 1
                }
            }
        }
    }
    
    private func completeOnboarding() {
        HapticFeedbackService.shared.lightImpact()
        if currentStep < onboardingSteps.count - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            hasCompletedOnboarding = true
        }
    }
}

struct OnboardingStep {
    let image: String
    let title: String
    let description: String
}

struct OnboardingStepView: View {
    let step: OnboardingStep
    @State private var isTextShown = false

    var body: some View {
        VStack(spacing: AppSpacing.xxl) {
            Spacer()
            
            Image(systemName: step.image)
                .font(.system(size: 100))
                .foregroundColor(Color.bankPrimary)
                .accessibilityHidden(true)
                .symbolRenderingMode(.hierarchical)
            
            StaggeredTextReveal(isShown: isTextShown) {
                Text(step.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(step.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .padding(.top, AppSpacing.xxl)
        .onAppear { isTextShown = true }
        .onChange(of: step.title) {
            isTextShown = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isTextShown = true
            }
        }
    }
}