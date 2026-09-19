import SwiftUI
import Combine
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@main
struct BankApp: App {
    @StateObject private var authenticationService = AuthenticationService()
    @StateObject private var transactionViewModel: TransactionViewModel
    @StateObject private var accountViewModel: AccountViewModel
    @ObservedObject private var settings = AppSettings.shared

    private let container: ModelContainer

    init() {
        let container = PersistenceController.shared
        self.container = container

        let context = container.mainContext
        let tvm = TransactionViewModel(modelContext: context)
        let avm = AccountViewModel(modelContext: context, transactionViewModel: tvm)
        _transactionViewModel = StateObject(wrappedValue: tvm)
        _accountViewModel = StateObject(wrappedValue: avm)

        Self.configureChrome()
    }

    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView {
                        showSplash = false
                    }
                } else if !hasCompletedOnboarding {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                } else if !authenticationService.hasPasscodeConfigured {
                    PasscodeSetupView()
                        .environmentObject(authenticationService)
                } else if authenticationService.isAuthenticated {
                    MainTabView()
                        .environmentObject(authenticationService)
                        .environmentObject(accountViewModel)
                        .environmentObject(transactionViewModel)
                } else {
                    LoginView()
                        .environmentObject(authenticationService)
                }
            }
            .modelContainer(container)
            .tint(Color.bankPrimary)
            .preferredColorScheme(settings.appearanceMode.colorScheme)
            .onChange(of: hasCompletedOnboarding) { _, completed in
                UserDefaults.standard.set(completed, forKey: "hasCompletedOnboarding")
            }
            .onChange(of: authenticationService.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    authenticationService.loadUser(from: container)
                }
            }
            .onAppear {
                SpotlightIndexManager.shared.indexAllAccounts(accountViewModel.accounts)
                let billerDescriptor = FetchDescriptor<Biller>()
                if let billers = try? container.mainContext.fetch(billerDescriptor) {
                    SpotlightIndexManager.shared.indexAllBillers(billers)
                }
            }
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 740)
        .windowResizability(.contentMinSize)
        #endif
    }

    private static func configureChrome() {
        #if canImport(UIKit) && os(iOS)
        // Leave bar appearances at system defaults so iOS 27 Liquid Glass
        // (and the user's Appearance → Liquid Glass slider) can apply.
        UINavigationBar.appearance().tintColor = UIColor(Color.bankPrimary)
        UITabBar.appearance().tintColor = UIColor(Color.bankPrimary)
        #endif
    }
}
