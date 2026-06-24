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
            LinearGradient(
                colors: [Color.bankPrimary.opacity(0.05), Color(UIColor.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    logoScale = 1
                    logoOpacity = 1
                }
            }
        }
        .background(Color(UIColor.systemBackground))
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
    
    var body: some View {
        VStack(spacing: AppSpacing.xxl) {
            Spacer()
            
            Image(systemName: step.image)
                .font(.system(size: 100))
                .foregroundColor(Color.bankPrimary)
                .accessibilityHidden(true)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: AppSpacing.md) {
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
            
            Spacer()
        }
        .padding(.top, AppSpacing.xxl)
    }
}