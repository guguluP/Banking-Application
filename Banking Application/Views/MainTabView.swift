import SwiftUI
import Combine
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct MainTabView: View {
    @EnvironmentObject var authenticationService: AuthenticationService
    @Environment(AccountViewModel.self) var accountViewModel
    @Environment(TransactionViewModel.self) var transactionViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedTab: AppTab = .home
    @State private var showLockView = false
    @State private var showChatbot = false
    @State private var hideForSwitcher = false

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
                .ignoresSafeArea()
                .zIndex(0)

            Group {
                if authenticationService.isDecoySession {
                    DecoyHomeView()
                } else if sizeClass == .regular {
                    regularLayout
                } else {
                    compactLayout
                }
            }
            .tint(Color.bankPrimary)
            .zIndex(1)
            .blur(radius: hideForSwitcher ? 24 : 0)

            InAppLiveActivityBanner()
                .zIndex(30)
                .allowsHitTesting(false)

            if showLockView {
                LockView(isVisible: $showLockView, authenticationService: authenticationService)
                    .transition(.opacity)
                    .zIndex(50)
            }
        }
        .sheet(isPresented: $authenticationService.isPresentingStepUpPasscode) {
            StepUpPasscodeSheet()
                .environmentObject(authenticationService)
        }
        .sheet(isPresented: $showChatbot) {
            ChatbotView()
                .environmentObject(authenticationService)
                .environment(accountViewModel)
                .environment(transactionViewModel)
                .presentationDetents(PlatformUI.isMac ? [.large] : [.medium, .large])
                .presentationDragIndicator(.visible)
        }
        #if canImport(UIKit)
        .overlay {
            ActivityTouchRelay {
                authenticationService.recordActivity()
            }
            .ignoresSafeArea()
        }
        #endif
        .onChange(of: authenticationService.isLocked) { _, locked in
            withAnimation(AppTheme.Animation.standard) {
                showLockView = locked
            }
        }
        .onChange(of: selectedTab) {
            HapticFeedbackService.shared.lightImpact()
        }
        .onChange(of: scenePhase) { _, newPhase in
            hideForSwitcher = newPhase != .active
            if newPhase == .active {
                BankImportPipeline.ingestCapturedSMS(in: modelContext)
            }
            if newPhase == .background, AppSettings.shared.isPasscodeLockEnabled {
                authenticationService.isLocked = true
            }
        }
        .task {
            await NotificationService.shared.requestAuthorizationIfNeeded()
            NotificationService.shared.rescheduleWeeklySummary()
        }
    }

    // MARK: - Compact (iPhone)

    private var compactLayout: some View {
        TabView(selection: $selectedTab) {
            tabRoot(for: .home)
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
                .tag(AppTab.home)
                .accessibilityLabel(AppTab.home.title)
                .accessibilityHint(AppTab.home.hint)

            tabRoot(for: .track)
                .tabItem { Label(AppTab.track.title, systemImage: AppTab.track.systemImage) }
                .tag(AppTab.track)
                .accessibilityLabel(AppTab.track.title)
                .accessibilityHint(AppTab.track.hint)

            tabRoot(for: .cards)
                .tabItem { Label(AppTab.cards.title, systemImage: AppTab.cards.systemImage) }
                .tag(AppTab.cards)
                .accessibilityLabel(AppTab.cards.title)
                .accessibilityHint(AppTab.cards.hint)

            tabRoot(for: .payments)
                .tabItem { Label(AppTab.payments.title, systemImage: AppTab.payments.systemImage) }
                .tag(AppTab.payments)
                .accessibilityLabel(AppTab.payments.title)
                .accessibilityHint(AppTab.payments.hint)

            tabRoot(for: .profile)
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
                .tag(AppTab.profile)
                .accessibilityLabel(AppTab.profile.title)
                .accessibilityHint(AppTab.profile.hint)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            Button {
                HapticFeedbackService.shared.lightImpact()
                showChatbot = true
            } label: {
                Label("AI Assistant", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Open AI Assistant")
        }
    }

    // MARK: - Regular (iPad / Mac)

    private var regularLayout: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                Text("BankSecure")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.bankPrimary)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(AppTab.allCases) { tab in
                            Button {
                                withAnimation(AppTheme.Animation.quick) {
                                    selectedTab = tab
                                }
                                HapticFeedbackService.shared.lightImpact()
                            } label: {
                                Label(tab.title, systemImage: tab.systemImage)
                                    .font(.body.weight(selectedTab == tab ? .semibold : .regular))
                                    .foregroundStyle(selectedTab == tab ? Color.white : Color.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background {
                                        if selectedTab == tab {
                                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                                                .fill(Color.bankPrimaryGradient)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tab.title)
                            .accessibilityHint(tab.hint)
                            .accessibilityAddTraits(selectedTab == tab ? [.isSelected, .isButton] : .isButton)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                .bankSoftScrollEdges()

                Spacer(minLength: 0)

                Button {
                    HapticFeedbackService.shared.lightImpact()
                    showChatbot = true
                } label: {
                    Label("Assistant", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.bankPrimary)
                .glassControl(cornerRadius: AppTheme.CornerRadius.medium, tint: Color.bankPrimary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
            }
            .navigationTitle("Menu")
        } detail: {
            tabRoot(for: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func tabRoot(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            AccountOverviewView()
        case .track:
            TrackView(accountViewModel: accountViewModel, transactionViewModel: transactionViewModel, modelContext: modelContext)
        case .cards:
            CardManagementView()
        case .payments:
            PaymentsView()
        case .profile:
            ProfileView()
        }
    }

}

// MARK: - Tabs

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home, track, cards, payments, profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .track: return "Track"
        case .cards: return "Cards"
        case .payments: return "Payments"
        case .profile: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .track: return "chart.line.uptrend.xyaxis"
        case .cards: return "creditcard.fill"
        case .payments: return "qrcode.viewfinder"
        case .profile: return "gearshape.fill"
        }
    }

    var hint: String {
        switch self {
        case .home: return "Accounts, balance, and recent activity"
        case .track: return "Log expenses, track budgets, and view spending analytics"
        case .cards: return "View and manage your debit and credit cards"
        case .payments: return "UPI payments and bill pay"
        case .profile: return "Profile, security, and app preferences"
        }
    }
}

#if canImport(UIKit)
/// Sees every touch so the inactivity timer resets, and returns nil from
/// hit testing so the navigation back button and the swipe-back gesture still receive the touch.
private struct ActivityTouchRelay: UIViewRepresentable {
    var onTouch: () -> Void

    func makeUIView(context: Context) -> PassThroughView {
        let view = PassThroughView()
        view.onTouch = onTouch
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: PassThroughView, context: Context) {
        uiView.onTouch = onTouch
    }

    final class PassThroughView: UIView {
        var onTouch: (() -> Void)?
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if bounds.contains(point) { onTouch?() }
            return nil
        }
    }
}
#endif

// MARK: - Lock

struct LockView: View {
    @Binding var isVisible: Bool
    @ObservedObject var authenticationService: AuthenticationService

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .transition(.opacity)

            GlassCard(tint: Color.bankPrimary) {
                VStack(spacing: AppSpacing.xl) {
                    ZStack {
                        Circle()
                            .fill(Color.bankPrimary.opacity(0.12))
                            .frame(width: 88, height: 88)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(Color.bankPrimary)
                            .symbolRenderingMode(.hierarchical)
                    }

                    VStack(spacing: 6) {
                        Text("App Locked")
                            .font(.title2.weight(.bold))
                        Text("Authenticate to continue")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

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
                        authenticationService.isAuthenticated = false
                        authenticationService.isLocked = false
                        isVisible = false
                    }
                    .padding(.horizontal)
                }
                .padding(AppSpacing.xl)
                .frame(maxWidth: 400)
            }
            .padding(AppSpacing.xl)
            .adaptiveContentWidth(440)
        }
    }
}
