import SwiftUI
import Combine
import SwiftData

struct TransferView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Beneficiary.nickname) private var allBeneficiaries: [Beneficiary]
    @StateObject private var viewModel = TransferViewModel()
    @State private var selectedFromAccount: Account?
    @State private var description: String = ""
    @State private var showingConfirmation = false
    @State private var showingSuccess = false
    @State private var showingAddBeneficiary = false
    
    private let quickAmounts: [Decimal] = [Decimal(100), Decimal(500), Decimal(1000), Decimal(5000)]
    
    private var myBeneficiaries: [Beneficiary] {
        guard let userId = authenticationService.user?.id else { return [] }
        return allBeneficiaries.filter { $0.userId == userId }
    }
    
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
                    
                    if !myBeneficiaries.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Saved Payees")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(myBeneficiaries) { beneficiary in
                                        Button(action: {
                                            viewModel.recipientAccount = beneficiary.accountNumber
                                            HapticFeedbackService.shared.lightImpact()
                                        }) {
                                            VStack(spacing: 4) {
                                                Circle()
                                                    .fill(Color.bankPrimary.opacity(0.15))
                                                    .frame(width: 44, height: 44)
                                                    .overlay(
                                                        Text(String(beneficiary.nickname.prefix(1)).uppercased())
                                                            .font(.headline)
                                                            .foregroundColor(Color.bankPrimary)
                                                    )
                                                Text(beneficiary.nickname)
                                                    .font(.caption2)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                    .frame(width: 60)
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .accessibilityLabel("Send to \(beneficiary.nickname)")
                                    }
                                    
                                    Button(action: { showingAddBeneficiary = true }) {
                                        VStack(spacing: 4) {
                                            Color.clear
                                                .frame(width: 44, height: 44)
                                                .glassControl(cornerRadius: 22)
                                                .overlay(
                                                    Image(systemName: "plus")
                                                        .font(.headline)
                                                        .foregroundColor(Color.bankPrimary)
                                                )
                                            Text("Add")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .frame(width: 60)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .accessibilityLabel("Add a new payee")
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        Button(action: { showingAddBeneficiary = true }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Add a payee to save them for next time")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .font(.subheadline)
                            .foregroundColor(Color.bankPrimary)
                            .padding()
                            .glassControl(cornerRadius: AppTheme.CornerRadius.medium)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                    }
                    
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
                                    .background(Color.bankGroupedBackground)
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
                            .autocorrectionDisabled(true)
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
            .overlay {
                if showingSuccess {
                    TransferSuccessOverlay(isPresented: $showingSuccess)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isProcessing)
            .navigationTitle("Transfer Money")
            .searchable(text: $viewModel.searchText, prompt: "Search accounts")
            .autocorrectionDisabled(true)
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
                Button("Authorize") {
                    requestBiometricAuth()
                }
            } message: {
                let amountText = CurrencyFormatter.shared.string(from: Decimal(string: viewModel.amount) ?? 0)
                Text("Transfer \(amountText) to \(viewModel.recipientAccount)?")
                    .accessibilityLabel("Confirm transfer of \(amountText) to account ending in \(viewModel.recipientAccount.suffix(4))")
            }
            .sheet(isPresented: $showingAddBeneficiary) {
                AddBeneficiaryView()
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
        showingConfirmation = false

        if authenticationService.canUseBiometrics {
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
        } else {
            // No biometrics enrolled on this device — fall back to the
            // device passcode rather than blocking the transfer outright.
            authenticationService.authenticateWithPasscode { success in
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
    }
    
    private func processTransfer() {
        guard let from = selectedFromAccount else { return }

        let succeeded = viewModel.performTransfer(from: from, description: description, in: modelContext)

        if succeeded {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showingSuccess = true
            }
            selectedFromAccount = nil
            description = ""
            accountViewModel.loadAccounts()
            transactionViewModel.loadAllTransactions()
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
            .background(Color.bankGroupedBackground)
            .cornerRadius(AppTheme.CornerRadius.small)
        }
        .accessibilityLabel(selection == nil ? "Select Account" : (selection?.nickname ?? "Account") + ": \(selection?.formattedAvailableBalance ?? "0") available")
    }
}

struct TransferSuccessOverlay: View {
    @Binding var isPresented: Bool
    @State private var checkmarkScale: CGFloat = 0.4

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: AppSpacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                    .scaleEffect(checkmarkScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                            checkmarkScale = 1.0
                        }
                    }

                Text("Transfer Complete")
                    .font(.headline)

                Text("Your money is on its way.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ModernButton(title: "Done", systemImage: nil, variant: .filled) {
                    dismiss()
                }
                .padding(.top, AppSpacing.sm)
            }
            .padding(AppSpacing.xl)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
            .padding(.horizontal, AppSpacing.xxl)
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
    }
}

struct TransferView_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.preview
        let context = container.mainContext
        let tvm = TransactionViewModel(modelContext: context)
        let avm = AccountViewModel(modelContext: context, transactionViewModel: tvm)
        return TransferView()
            .environmentObject(avm)
            .environmentObject(tvm)
            .environmentObject(AuthenticationService())
            .modelContainer(container)
    }
}
