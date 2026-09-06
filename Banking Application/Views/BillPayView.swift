import SwiftUI
import Combine
import SwiftData

/// Sheet-presented bill payment flow (used from Home's Bill Pay action).
/// Thin wrapper around `BillPayContent` — see that type for the actual
/// form, which is also embedded directly (no navigation wrapper) inside
/// the Payments tab.
struct BillPayView: View {
    var body: some View {
        NavigationStack {
            BillPayContent()
                .navigationTitle("Pay Bills")
        }
    }
}

/// The bill payment form and logic, shared by both the sheet-presented
/// `BillPayView` (Home tab's Bill Pay action) and the inline `PaymentsView`
/// tab. Previously these were two separately maintained near-duplicates —
/// this is the single source of truth now.
struct BillPayContent: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Biller.name) private var billers: [Biller]
    @State private var selectedBiller: Biller?
    @State private var selectedAccount: Account?
    @State private var amount = ""
    @StateObject private var viewModel = BillPayViewModel()
    @State private var showingConfirmation = false
    @State private var showingBiometric = false
    @State private var showingConfetti = false
    @State private var cashbackEarned: Decimal?
    /// The Payments tab already provides its own top-level search field, so
    /// it passes `false` here — a second, nested `.searchable` in the same
    /// navigation stack is invalid SwiftUI and only the outer one wins.
    var enableSearch: Bool = true
    /// When embedded in a parent that owns its own search field (Payments
    /// tab), the parent passes its text in here so filtering still works
    /// even though this view isn't the one presenting the search UI.
    var externalSearchText: String = ""
    
    private let quickAmounts: [Decimal] = [Decimal(100), Decimal(500), Decimal(1000), Decimal(2000)]

    /// `viewModel.searchText` existed before but was never actually used to
    /// filter anything — the search field looked functional but wasn't.
    private var filteredBillers: [Biller] {
        let query = enableSearch ? viewModel.searchText : externalSearchText
        guard !query.isEmpty else { return billers }
        return billers.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                BillerPicker(selection: $selectedBiller, billers: filteredBillers)
                
                AccountPicker(selection: $selectedAccount, accounts: accountViewModel.accounts)
                
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ModernTextField(
                        label: "Amount",
                        placeholder: "0.00",
                        text: $amount,
                        systemImage: "indianrupee.sign",
                        keyboardType: .decimalPad
                    )
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickAmounts, id: \.self) { quickAmount in
                                Button(CurrencyFormatter.shared.string(from: quickAmount)) {
                                    amount = NSDecimalNumber(decimal: quickAmount).stringValue
                                    HapticFeedbackService.shared.lightImpact()
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.bankGroupedBackground)
                                .cornerRadius(AppTheme.CornerRadius.pill)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                if let error = viewModel.error {
                    ErrorBannerModern(error: error)
                        .padding(.horizontal)
                }
                
                ModernButton(
                    title: viewModel.isProcessing ? "Processing..." : "Pay Bill",
                    systemImage: viewModel.isProcessing ? nil : "doc.text.fill",
                    variant: isFormValid ? .filled : .glass
                ) {
                    initiatePayment()
                }
                .disabled(!isFormValid || viewModel.isProcessing)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .searchableIf(enableSearch, text: $viewModel.searchText, prompt: "Search billers")
        .autocorrectionDisabled(true)
        .alert("Confirm Payment", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Pay") {
                requestBiometricAuth()
            }
        } message: {
            Text("Pay \(CurrencyFormatter.shared.string(from: Decimal(string: amount) ?? 0)) to \(selectedBiller?.displayName ?? "Biller")?")
        }
        .alert("Biometric Required", isPresented: $showingBiometric) {
            Button("Cancel", role: .cancel) { }
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
        } message: {
            Text("Biometric authentication is required. Enable Face ID or Touch ID in Settings.")
        }
        .overlay {
            ConfettiView(isActive: $showingConfetti)
        }
        .safeAreaInset(edge: .top) {
            if let cashbackEarned {
                CashbackToast(amount: cashbackEarned)
                    .padding(.horizontal)
                    .padding(.top, AppSpacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cashbackEarned)
        .accessibilityElement(children: .contain)
    }
    
    private var isFormValid: Bool {
        selectedBiller != nil && selectedAccount != nil && Decimal(string: amount) ?? 0 > 0
    }
    
    private func initiatePayment() {
        if let amountDecimal = Decimal(string: amount), amountDecimal <= 0 {
            viewModel.error = .invalidAmount
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        if let account = selectedAccount, let amountDecimal = Decimal(string: amount), amountDecimal > NSDecimalNumber(decimal: account.availableBalance).decimalValue {
            viewModel.error = .insufficientFunds
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        showingConfirmation = true
    }
    
    private func requestBiometricAuth() {
        guard authenticationService.canUseBiometrics else {
            viewModel.error = .biometricFailed
            HapticFeedbackService.shared.errorOccurred()
            showingBiometric = true
            return
        }
        
        showingConfirmation = false
        
        authenticationService.authenticateWithBiometrics { success in
            if success {
                processPayment()
            } else {
                viewModel.error = .authenticationFailed
                HapticFeedbackService.shared.errorOccurred()
            }
            showingBiometric = false
        }
    }
    
    private func processPayment() {
        guard let biller = selectedBiller, let account = selectedAccount else { return }
        viewModel.amount = amount

        let succeeded = viewModel.payBill(biller: biller, from: account, in: modelContext)

        if succeeded {
            if let earned = viewModel.lastCashbackEarned {
                cashbackEarned = earned
                showingConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    cashbackEarned = nil
                }
            }
            selectedBiller = nil
            selectedAccount = nil
            amount = ""
            accountViewModel.loadAccounts()
            transactionViewModel.loadAllTransactions()
        }
    }
}

struct CashbackToast: View {
    let amount: Decimal

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "sparkles")
                .foregroundStyle(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                )
            Text("You earned \(CurrencyFormatter.shared.string(from: amount)) cashback!")
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
        .accessibilityElement(children: .combine)
    }
}

struct BillPayView_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.preview
        let context = container.mainContext
        let tvm = TransactionViewModel(modelContext: context)
        let avm = AccountViewModel(modelContext: context, transactionViewModel: tvm)
        return NavigationStack {
            BillPayView()
                .environmentObject(avm)
                .environmentObject(tvm)
                .environmentObject(AuthenticationService())
        }
        .modelContainer(container)
    }
}
