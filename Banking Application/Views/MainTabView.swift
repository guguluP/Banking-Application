import SwiftUI
import Combine
import SwiftData

struct MainTabView: View {
    @EnvironmentObject var authenticationService: AuthenticationService
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var showLockView = false
    @State private var showChatbot = false

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                AccountOverviewView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)
                    .accessibilityLabel("Home")
                    .accessibilityHint("Accounts, balance, and recent activity")

                CardManagementView()
                    .tabItem {
                        Label("Cards", systemImage: "creditcard.fill")
                    }
                    .tag(1)
                    .accessibilityLabel("Cards")
                    .accessibilityHint("View and manage your debit and credit cards")

                TransferView()
                    .tabItem {
                        Label("Transfer", systemImage: "arrow.left.arrow.right")
                    }
                    .tag(2)
                    .accessibilityLabel("Transfer")
                    .accessibilityHint("Transfer money between accounts")

                PaymentsView()
                    .tabItem {
                        Label("Payments", systemImage: "qrcode.viewfinder")
                    }
                    .tag(3)
                    .accessibilityLabel("Payments")
                    .accessibilityHint("UPI payments and bill pay")

                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(4)
                    .accessibilityLabel("Profile")
                    .accessibilityHint("Manage your profile and settings")
            }
            .tint(Color.bankPrimary)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .onChange(of: authenticationService.isLocked) { _, locked in
                withAnimation(.easeInOut(duration: 0.25)) {
                    showLockView = locked
                }
            }
            .onChange(of: selectedTab) {
                HapticFeedbackService.shared.lightImpact()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background, AppSettings.shared.isPasscodeLockEnabled {
                    authenticationService.isLocked = true
                }
            }

            if !showLockView {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            HapticFeedbackService.shared.lightImpact()
                            showChatbot = true
                        }) {
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Color.bankPrimary)
                                .frame(width: 56, height: 56)
                                .glassControl(cornerRadius: AppTheme.CornerRadius.pill, tint: Color.bankPrimary)
                        }
                        .accessibilityLabel("Open assistant")
                        .padding(.trailing, AppSpacing.lg)
                        .padding(.bottom, 70)
                    }
                }
                .transition(.opacity)
            }

            if showLockView {
                LockView(isVisible: $showLockView, authenticationService: authenticationService)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showChatbot) {
            ChatbotView()
                .environmentObject(authenticationService)
                .environmentObject(accountViewModel)
                .environmentObject(transactionViewModel)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in authenticationService.recordActivity() }
        )
    }
}

struct LockView: View {
    @Binding var isVisible: Bool
    @ObservedObject var authenticationService: AuthenticationService

    var body: some View {
        ZStack {
            // Keep the ambient mesh visible under a dimming veil.
            AnimatedMeshBackground()
                .ignoresSafeArea()
            Color.black.opacity(0.35)
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

                    if authenticationService.isBiometricsLoginEnabled {
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

                    ModernButton(
                        title: "Use Passcode",
                        systemImage: "lock.rectangle",
                        variant: .outlined
                    ) {
                        // Dismiss lock overlay only after full re-auth path;
                        // require user to re-enter via logging out session lock.
                        authenticationService.isAuthenticated = false
                        authenticationService.isLocked = false
                        isVisible = false
                    }
                    .padding(.horizontal)
                }
                .padding(AppSpacing.xl)
            }
            .padding(AppSpacing.xl)
        }
    }
}
