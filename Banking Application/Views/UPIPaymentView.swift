import SwiftUI
import Combine
import SwiftData

struct UPIPaymentView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @Environment(\.modelContext) private var modelContext
    @State private var selectedAccount: Account?
    @State private var upiId = ""
    @State private var amount = ""
    @State private var remarks = ""
    @State private var showingScanner = false
    @State private var showingConfirmation = false
    @State private var error: AppError?
    @State private var isProcessing = false
    @State private var showingPaymentSuccess = false
    @State private var successAmount: String = ""
    
    private let quickAmounts: [Decimal] = [Decimal(100), Decimal(500), Decimal(1000), Decimal(2000)]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("From Account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        AccountPicker(selection: $selectedAccount, accounts: accountViewModel.accounts)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("UPI ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            ModernTextField(
                                label: "UPI ID",
                                placeholder: "name@upi",
                                text: $upiId,
                                systemImage: "person.crop.circle",
                                keyboardType: .emailAddress
                            )
                            
                            Button(action: { showingScanner = true }) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title3)
                                    .foregroundColor(Color.bankPrimary)
                                    .frame(width: 44, height: 44)
                                    .background(Color(UIColor.systemGroupedBackground))
                                    .cornerRadius(AppTheme.CornerRadius.pill)
                            }
                            .accessibilityLabel("Scan QR Code")
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    
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
                                    .accessibilityLabel("Quick amount: \(CurrencyFormatter.shared.string(from: quickAmount))")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Remarks (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Add remarks", text: $remarks)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled(true)
                            .accessibilityLabel("Remarks")
                    }
                    .padding(.horizontal)
                    
                    if let error = error {
                        ErrorBannerModern(error: error)
                            .padding(.horizontal)
                    }
                    
                    ModernButton(
                        title: isProcessing ? "Processing..." : "Pay via UPI with Face ID",
                        systemImage: isProcessing ? nil : "faceid",
                        variant: isFormValid && !isProcessing ? .filled : .glass
                    ) {
                        initiateUPIPayment()
                    }
                    .disabled(!isFormValid || isProcessing)
                    .padding(.horizontal)
                    
                    if !accountViewModel.upiTransactions.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Recent Transactions")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            
                            ForEach(accountViewModel.upiTransactions.prefix(3)) { txn in
                                UPITransactionRow(transaction: txn)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("UPI Payment")
            .sheet(isPresented: $showingScanner) {
                UPCScannerView(upiId: $upiId)
            }
            .alert("Confirm UPI Payment", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Authorize", role: .destructive) {
                    requestBiometricAuth()
                }
            } message: {
                Text("Pay \(CurrencyFormatter.shared.string(from: Decimal(string: amount) ?? 0)) to \(upiId)?")
                    .accessibilityLabel("Confirm payment of \(CurrencyFormatter.shared.string(from: Decimal(string: amount) ?? 0)) to \(upiId)")
            }
        }
        .overlay {
            if showingPaymentSuccess {
                PaymentSuccessOverlay(amount: successAmount, subtitle: "UPI Payment Sent", isPresented: $showingPaymentSuccess)
            }
        }
        .accessibilityElement(children: .contain)
    }
    
    private var isFormValid: Bool {
        guard let account = selectedAccount else { return false }
        guard let amountDecimal = Decimal(string: amount), amountDecimal > 0 else { return false }
        guard !upiId.isEmpty else { return false }
        guard isValidUPIId else { return false }
        guard amountDecimal <= account.availableBalance else { return false }
        return true
    }
    
    private var isValidUPIId: Bool {
        upiId.contains("@")
    }
    
    private func initiateUPIPayment() {
        error = nil
        
        guard isValidUPIId else {
            error = .unknownError("Invalid UPI ID format (e.g., name@upi)")
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        guard let amountDecimal = Decimal(string: amount), amountDecimal > 0 else {
            error = .invalidAmount
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        guard let account = selectedAccount, amountDecimal <= account.availableBalance else {
            error = .insufficientFunds
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        showingConfirmation = true
    }
    
    private func requestBiometricAuth() {
        guard authenticationService.canUseBiometrics else {
            error = .biometricFailed
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        showingConfirmation = false
        
        authenticationService.authenticateWithBiometrics { success in
            if success {
                processUPIPayment()
            } else {
                error = .authenticationFailed
                HapticFeedbackService.shared.errorOccurred()
            }
        }
    }
    
    private func processUPIPayment() {
        guard let amountDecimal = Decimal(string: amount) else { return }
        guard let account = selectedAccount else { return }

        guard amountDecimal <= account.availableBalance else {
            error = .insufficientFunds
            HapticFeedbackService.shared.errorOccurred()
            return
        }

        isProcessing = true

        // Previously this only logged a standalone UPITransaction record and
        // never actually reduced the account's balance — the money was never
        // really "sent". Now it debits the account and writes a proper
        // Transaction too, same as transfers and bill payments.
        account.balance -= amountDecimal
        account.availableBalance -= amountDecimal

        let txn = Transaction(
            accountId: account.id,
            type: .payment,
            amount: amountDecimal,
            description: remarks.isEmpty ? "UPI payment to \(upiId)" : remarks,
            counterparty: upiId,
            transactionDate: Date(),
            category: "UPI",
            status: .completed
        )
        txn.account = account
        modelContext.insert(txn)

        do {
            try modelContext.save()
            accountViewModel.addUPITransaction(upiId: upiId, amount: amountDecimal)
            accountViewModel.loadAccounts()
            transactionViewModel.loadAllTransactions()

            isProcessing = false
            successAmount = CurrencyFormatter.shared.string(from: amountDecimal)
            withAnimation(.easeInOut(duration: 0.25)) {
                showingPaymentSuccess = true
            }
            resetForm()
        } catch {
            account.balance += amountDecimal
            account.availableBalance += amountDecimal
            modelContext.delete(txn)
            isProcessing = false
            self.error = .transactionFailed
            HapticFeedbackService.shared.errorOccurred()
        }
    }
    
    private func resetForm() {
        selectedAccount = nil
        upiId = ""
        amount = ""
        remarks = ""
        error = nil
    }
}

struct UPITransactionRow: View {
    let transaction: UPITransaction
    
    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading) {
                    Text(transaction.upiId)
                        .font(.subheadline)
                    Text(transaction.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(CurrencyFormatter.shared.string(from: transaction.amount))
                    .foregroundColor(.green)
            }
            .padding()
        }
        .accessibilityElement(children: .combine)
    }
}

struct UPCScannerView: View {
    @Binding var upiId: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 100))
                    .foregroundColor(.secondary)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                    .padding()
                
                Text("Scanner would open here")
                    .font(.title3)
                
                Button("Simulate Scan: rahul@upi") {
                    upiId = "rahul@upi"
                    dismiss()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Scan QR Code")
            .toolbar {
                Button("Cancel") { dismiss() }
                    .accessibilityLabel("Cancel scanning")
            }
        }
    }
}

struct UPIPaymentView_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.preview
        let context = container.mainContext
        let tvm = TransactionViewModel(modelContext: context)
        let avm = AccountViewModel(modelContext: context, transactionViewModel: tvm)
        return UPIPaymentView()
            .environmentObject(avm)
            .environmentObject(tvm)
            .environmentObject(AuthenticationService())
            .modelContainer(container)
    }
}
