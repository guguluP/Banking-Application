import SwiftUI

struct TransferView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @StateObject private var viewModel = TransferViewModel()
    @State private var selectedFromAccount: Account?
    @State private var description: String = ""
    @State private var showingConfirmation = false
    @State private var showingBiometric = false
    
    private let quickAmounts: [Decimal] = [Decimal(100), Decimal(500), Decimal(1000), Decimal(5000)]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("From Account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        AccountPicker(selection: $selectedFromAccount, accounts: accountViewModel.accounts)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Recipient Account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ModernTextField(
                            label: "Recipient Account",
                            placeholder: "Enter account number",
                            text: $viewModel.recipientAccount,
                            isValid: viewModel.isRecipientValid,
                            errorMessage: viewModel.recipientError,
                            keyboardType: .numberPad
                        )
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Amount")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ModernTextField(
                            label: "Amount",
                            placeholder: "0.00",
                            text: $viewModel.amount,
                            isValid: viewModel.isAmountValid,
                            errorMessage: viewModel.amountError,
                            systemImage: "indianrupee.sign",
                            keyboardType: .decimalPad
                        )
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(quickAmounts, id: \.self) { amount in
                                    Button(CurrencyFormatter.shared.string(from: amount)) {
                                        viewModel.amount = NSDecimalNumber(decimal: amount).stringValue
                                        HapticFeedbackService.shared.lightImpact()
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(UIColor.systemGroupedBackground))
                                    .cornerRadius(AppTheme.CornerRadius.pill)
                                    .accessibilityLabel("Quick amount: \(CurrencyFormatter.shared.string(from: amount))")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Description (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Description", text: $description)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .accessibilityLabel("Description")
                    }
                    .padding(.horizontal)
                    
                    if let error = viewModel.error {
                        ErrorBannerModern(error: error)
                            .padding(.horizontal)
                    }
                    
                    ModernButton(
                        title: viewModel.isProcessing ? "Processing..." : "Transfer Money",
                        systemImage: viewModel.isProcessing ? nil : "arrow.left.arrow.right",
                        variant: isFormValid ? .filled : .glass
                    ) {
                        initiateTransfer()
                    }
                    .disabled(!isFormValid || viewModel.isProcessing)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Transfer Money")
            .searchable(text: $viewModel.searchText, prompt: "Search accounts")
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        hideKeyboard()
                    }
                    .accessibilityLabel("Dismiss keyboard")
                }
            }
            .alert("Confirm Transfer", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Authorize", role: .destructive) {
                    requestBiometricAuth()
                }
            } message: {
                let amountText = CurrencyFormatter.shared.string(from: Decimal(string: viewModel.amount) ?? 0)
                Text("Transfer \(amountText) to \(viewModel.recipientAccount)?")
                    .accessibilityLabel("Confirm transfer of \(amountText) to account ending in \(viewModel.recipientAccount.suffix(4))")
            }
            .alert("Face ID Required", isPresented: $showingBiometric) {
                Button("OK", role: .cancel) { }
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            } message: {
                Text("Biometric authentication is required for transfers. Enable Face ID or Touch ID in Settings.")
            }
        }
        .accessibilityElement(children: .contain)
    }
    
    private var isFormValid: Bool {
        guard let from = selectedFromAccount else { return false }
        guard let amountDecimal = Decimal(string: viewModel.amount), amountDecimal > 0 else { return false }
        guard amountDecimal <= from.availableBalance else { return false }
        return viewModel.isFormValid
    }
    
    private func initiateTransfer() {
        viewModel.clearError()
        
        guard let from = selectedFromAccount else {
            viewModel.error = .invalidInput
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        let recipient = viewModel.recipientAccount.trimmingCharacters(in: .whitespaces)
        guard !recipient.isEmpty else {
            viewModel.error = .invalidInput
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        guard recipient != from.accountNumber else {
            viewModel.error = .sameAccount
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        guard viewModel.validateForm() else { return }
        
        guard let amountDecimal = Decimal(string: viewModel.amount) else {
            viewModel.error = .invalidAmount
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        guard amountDecimal <= from.availableBalance else {
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
            Task { @MainActor in
                if success {
                    processTransfer()
                } else {
                    viewModel.error = .authenticationFailed
                    HapticFeedbackService.shared.errorOccurred()
                }
            }
        }
    }
    
    private func processTransfer() {
        guard Decimal(string: viewModel.amount) ?? 0 > 0 else { return }
        
        viewModel.isProcessing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            viewModel.isProcessing = false
            HapticFeedbackService.shared.success()
            
            selectedFromAccount = nil
            viewModel.recipientAccount = ""
            viewModel.amount = ""
            description = ""
            
            accountViewModel.loadAccounts()
        }
    }
    
    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

struct AccountPicker: View {
    @Binding var selection: Account?
    let accounts: [Account]
    
    var body: some View {
        Menu {
            ForEach(accounts) { account in
                Button(action: { selection = account }) {
                    VStack(alignment: .leading) {
                        Text(account.nickname ?? "Account")
                        Text(account.formattedAvailableBalance)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let account = selection {
                        Text(account.nickname ?? "Account")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text("Available: \(account.formattedAvailableBalance)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Select Account")
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
            .cornerRadius(AppTheme.CornerRadius.small)
        }
        .accessibilityLabel(selection == nil ? "Select Account" : (selection?.nickname ?? "Account") + ": \(selection?.formattedAvailableBalance ?? "0") available")
    }
}

struct TransferView_Previews: PreviewProvider {
    static var previews: some View {
        TransferView()
            .environmentObject(AccountViewModel(transactionViewModel: TransactionViewModel()))
            .environmentObject(AuthenticationService())
    }
}
