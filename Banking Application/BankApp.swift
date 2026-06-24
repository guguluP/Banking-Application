import SwiftUI

@main
struct BankApp: App {
    @StateObject private var authenticationService = AuthenticationService()
    @StateObject private var transactionViewModel: TransactionViewModel
    @StateObject private var accountViewModel: AccountViewModel
    
    init() {
        let tvm = TransactionViewModel()
        let avm = AccountViewModel(transactionViewModel: tvm)
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
            .onChange(of: hasCompletedOnboarding) { _, completed in
                UserDefaults.standard.set(completed, forKey: "hasCompletedOnboarding")
            }
            .onAppear {
                // Index accounts and billers for Spotlight search
                SpotlightIndexManager.shared.indexAllAccounts(accountViewModel.accounts)
                SpotlightIndexManager.shared.indexAllBillers([
                    Biller(id: "bil_001", userId: "user_001", name: "Electric Company", accountNumber: "123456789", nickname: "Electric Bill"),
                    Biller(id: "bil_002", userId: "user_001", name: "Water Services", accountNumber: "987654321", nickname: "Water Bill"),
                    Biller(id: "bil_003", userId: "user_001", name: "Internet Provider", accountNumber: "555555555", nickname: "Internet Bill"),
                    Biller(id: "bil_004", userId: "user_001", name: "Phone Carrier", accountNumber: "111111111", nickname: "Mobile Phone")
                ])
            }
        }
    }
}