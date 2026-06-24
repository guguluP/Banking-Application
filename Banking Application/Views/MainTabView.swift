import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authenticationService: AuthenticationService
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @State private var selectedTab = 0
    @State private var showLockView = false
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                AccountOverviewView()
                    .tabItem {
                        Label("Accounts", systemImage: "creditcard.fill")
                    }
                    .tag(0)
                    .accessibilityLabel("Accounts")
                    .accessibilityHint("View your accounts and cards")
                
                TransferView()
                    .tabItem {
                        Label("Transfer", systemImage: "arrow.left.arrow.right")
                    }
                    .tag(1)
                    .accessibilityLabel("Transfer")
                    .accessibilityHint("Transfer money between accounts")
                
                PaymentsView()
                    .tabItem {
                        Label("Payments", systemImage: "qrcode.viewfinder")
                    }
                    .tag(2)
                    .accessibilityLabel("Payments")
                    .accessibilityHint("UPI payments and bill pay")
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(3)
                    .accessibilityLabel("Profile")
                    .accessibilityHint("Manage your profile and settings")
            }
            .tint(Color.bankPrimary)
            .onChange(of: authenticationService.isAuthenticated) { _, newValue in
                if !newValue {
                    showLockView = true
                }
            }
            .onChange(of: selectedTab) {
                HapticFeedbackService.shared.lightImpact()
            }
            
            if showLockView {
                LockView(isVisible: $showLockView, authenticationService: authenticationService)
            }
        }
    }
}

struct LockView: View {
    @Binding var isVisible: Bool
    @ObservedObject var authenticationService: AuthenticationService
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .transition(.opacity)
            
            GlassCard {
                VStack(spacing: AppSpacing.xl) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color.bankPrimary)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("App Locked")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Authenticate to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if authenticationService.canUseBiometrics {
                        ModernButton(
                            title: "Unlock with \(authenticationService.biometryTypeString)",
                            systemImage: authenticationService.biometryTypeString == "Face ID" ? "faceid" : "touchid",
                            variant: .filled
                        ) {
                            authenticationService.authenticateWithBiometrics { success in
                                if success {
                                    isVisible = false
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if authenticationService.isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
                .padding()
            }
            .padding(.horizontal, 40)
        }
        .zIndex(1)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        let transactionViewModel = TransactionViewModel()
        let accountViewModel = AccountViewModel(transactionViewModel: transactionViewModel)
        return MainTabView()
            .environmentObject(AuthenticationService())
            .environmentObject(accountViewModel)
            .environmentObject(transactionViewModel)
    }
}