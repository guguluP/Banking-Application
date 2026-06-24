import SwiftUI

struct BillPayView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @State private var selectedBiller: Biller?
    @State private var selectedAccount: Account?
    @State private var amount = ""
    @StateObject private var viewModel = BillPayViewModel()
    @State private var showingConfirmation = false
    @State private var showingBiometric = false
    
    private let quickAmounts: [Decimal] = [Decimal(100), Decimal(500), Decimal(1000), Decimal(2000)]
    private let billers: [Biller] = [
        Biller(id: "bil_001", userId: "user_001", name: "Electric Company", accountNumber: "123456789", nickname: "Electric Bill"),
        Biller(id: "bil_002", userId: "user_001", name: "Water Services", accountNumber: "987654321", nickname: "Water Bill"),
        Biller(id: "bil_003", userId: "user_001", name: "Internet Provider", accountNumber: "555555555", nickname: "Internet Bill"),
        Biller(id: "bil_004", userId: "user_001", name: "Phone Carrier", accountNumber: "111111111", nickname: "Mobile Phone")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    BillerPicker(selection: $selectedBiller, billers: billers)
                    
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
                                    .background(Color(UIColor.systemGroupedBackground))
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
            .navigationTitle("Pay Bills")
            .searchable(text: $viewModel.searchText, prompt: "Search billers")
            .alert(isPresented: $showingConfirmation) {
                Alert(
                    title: Text("Confirm Payment"),
                    message: Text("Pay \(CurrencyFormatter.shared.string(from: Decimal(string: amount) ?? 0)) to \(selectedBiller?.displayName ?? "Biller")?"),
                    primaryButton: .default(Text("Cancel")),
                    secondaryButton: .destructive(Text("Pay")) {
                        requestBiometricAuth()
                    }
                )
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
        }
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
            DispatchQueue.main.async {
                if success {
                    processPayment()
                } else {
                    viewModel.error = .authenticationFailed
                    HapticFeedbackService.shared.errorOccurred()
                }
                showingBiometric = false
            }
        }
    }
    
    private func processPayment() {
        viewModel.isProcessing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            viewModel.isProcessing = false
            HapticFeedbackService.shared.success()
            
            selectedBiller = nil
            selectedAccount = nil
            amount = ""
            
            accountViewModel.loadAccounts()
        }
    }
}

struct BillPayView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            BillPayView()
                .environmentObject(AccountViewModel(transactionViewModel: TransactionViewModel()))
                .environmentObject(AuthenticationService())
        }
    }
}