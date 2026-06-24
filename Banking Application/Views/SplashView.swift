import SwiftUI

struct SplashView: View {
    let onDismiss: () -> Void
    
    @State private var animateLogo = false
    @State private var animateDots = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.bankPrimary.opacity(0.1), Color(UIColor.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: AppSpacing.xxl) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color.bankPrimary)
                    .scaleEffect(animateLogo ? 1 : 0.5)
                    .opacity(animateLogo ? 1 : 0)
                    .rotationEffect(.degrees(animateLogo ? 0 : -180))
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateLogo)
                
                VStack(spacing: 8) {
                    Text("BankSecure")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.primary)
                        .opacity(animateLogo ? 1 : 0)
                        .offset(y: animateLogo ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.2), value: animateLogo)
                    
                    Text("Your trusted banking companion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .opacity(animateLogo ? 1 : 0)
                        .offset(y: animateLogo ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.3), value: animateLogo)
                }
                
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.bankPrimary)
                            .frame(width: 8, height: 8)
                            .scaleEffect(animateDots ? 1 : 0.5)
                            .opacity(animateDots ? 1 : 0.3)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.6)
                                .delay(Double(index) * 0.2),
                                value: animateDots
                            )
                    }
                }
                .opacity(animateLogo ? 1 : 0)
            }
        }
        .onAppear {
            animateLogo = true
            animateDots = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onDismiss()
            }
        }
    }
}