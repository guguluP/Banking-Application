import SwiftUI
import Combine
import SwiftData

struct BillPayEmbedded: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Biller.name) private var billers: [Biller]
    @State private var selectedBiller: Biller?
    @State private var selectedAccount: Account?
    @State private var amount: String = ""
    @State private var showingConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var errorCode: PaymentError?
    @State private var isProcessing = false
    
    private let quickAmounts: [Decimal] = [Decimal(100), Decimal(500), Decimal(1000), Decimal(2000)]
    
    var body: some View {
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
                
                if let error = errorCode {
                    ErrorBanner(error: error)
                        .padding(.horizontal)
                }
                
                ModernButton(
                    title: isProcessing ? "Processing..." : "Pay Bill",
                    systemImage: isProcessing ? nil : "doc.text.fill",
                    variant: isFormValid ? .filled : .glass
                ) {
                    initiatePayment()
                }
                .disabled(!isFormValid || isProcessing)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .alert(isPresented: $showingError) {
            Alert(
                title: Text(errorCode?.rawValue ?? "Payment Successful"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK")) {
                    errorCode = nil
                }
            )
        }
        .alert("Confirm Payment", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Pay", role: .destructive) {
                requestBiometricAuth()
            }
        } message: {
            Text("Pay \(CurrencyFormatter.shared.string(from: Decimal(string: amount) ?? 0)) to \(selectedBiller?.displayName ?? "Biller")?")
        }
    }
    
    private var isFormValid: Bool {
        selectedBiller != nil && selectedAccount != nil && Decimal(string: amount) ?? 0 > 0
    }
    
    private func initiatePayment() {
        if let amountDecimal = Decimal(string: amount), amountDecimal <= 0 {
            errorCode = .invalidAmount
            errorMessage = "Please enter a valid amount greater than zero."
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        if let account = selectedAccount, let amountDecimal = Decimal(string: amount), amountDecimal > NSDecimalNumber(decimal: account.availableBalance).decimalValue {
            errorCode = .insufficientBalance
            errorMessage = "Insufficient balance. Available: \(account.formattedAvailableBalance)"
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        showingConfirmation = true
    }
    
    private func requestBiometricAuth() {
        guard authenticationService.canUseBiometrics else {
            errorCode = .authenticationFailed
            errorMessage = "Biometric authentication is required for bill payments."
            HapticFeedbackService.shared.errorOccurred()
            showingError = true
            return
        }
        
        showingConfirmation = false
        
        authenticationService.authenticateWithBiometrics { success in
            if success {
                processPayment()
            } else {
                errorCode = .authenticationFailed
                errorMessage = "Authentication failed. Please try again."
                HapticFeedbackService.shared.errorOccurred()
                showingError = true
            }
        }
    }
    
    private func processPayment() {
        guard let biller = selectedBiller, let account = selectedAccount,
              let amountDecimal = Decimal(string: amount) else { return }

        isProcessing = true

        guard amountDecimal <= account.availableBalance else {
            isProcessing = false
            errorCode = .insufficientBalance
            errorMessage = "Insufficient balance. Available: \(account.formattedAvailableBalance)"
            HapticFeedbackService.shared.errorOccurred()
            showingError = true
            return
        }

        account.balance -= amountDecimal
        account.availableBalance -= amountDecimal

        let txn = Transaction(
            accountId: account.id,
            type: .payment,
            amount: amountDecimal,
            description: biller.displayName,
            counterparty: biller.name,
            transactionDate: Date(),
            category: "Payment",
            status: .completed
        )
        txn.account = account
        modelContext.insert(txn)

        do {
            try modelContext.save()
            isProcessing = false
            errorCode = nil
            errorMessage = "Payment successful!"
            HapticFeedbackService.shared.success()
            showingError = true

            selectedBiller = nil
            selectedAccount = nil
            amount = ""

            accountViewModel.loadAccounts()
            transactionViewModel.loadAllTransactions()
        } catch {
            account.balance += amountDecimal
            account.availableBalance += amountDecimal
            modelContext.delete(txn)
            isProcessing = false
            errorCode = .authenticationFailed
            errorMessage = "The payment could not be completed. Please try again."
            HapticFeedbackService.shared.errorOccurred()
            showingError = true
        }
    }
}
