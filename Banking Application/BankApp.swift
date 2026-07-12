import SwiftUI
import Combine
import SwiftData

@main
struct BankApp: App {
    @StateObject private var authenticationService = AuthenticationService()
    @StateObject private var transactionViewModel: TransactionViewModel
    @StateObject private var accountViewModel: AccountViewModel

    private let container: ModelContainer

    init() {
        let container = PersistenceController.shared
        self.container = container

        let context = container.mainContext
        let tvm = TransactionViewModel(modelContext: context)
        let avm = AccountViewModel(modelContext: context, transactionViewModel: tvm)
        _transactionViewModel = StateObject(wrappedValue: tvm)
        _accountViewModel = StateObject(wrappedValue: avm)

        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
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
                    // First run on this device: no passcode hash exists in the
                    // Keychain yet, so the person must create one before they
                    // can reach any account data.
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
            .onChange(of: hasCompletedOnboarding) { _, completed in
                UserDefaults.standard.set(completed, forKey: "hasCompletedOnboarding")
            }
            .onChange(of: authenticationService.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    authenticationService.loadUser(from: container)
                }
            }
            .onAppear {
                // Index accounts and billers for Spotlight search using the
                // real, persisted data instead of a hardcoded duplicate list.
                SpotlightIndexManager.shared.indexAllAccounts(accountViewModel.accounts)
                let billerDescriptor = FetchDescriptor<Biller>()
                if let billers = try? container.mainContext.fetch(billerDescriptor) {
                    SpotlightIndexManager.shared.indexAllBillers(billers)
                }
            }
        }
    }
}
