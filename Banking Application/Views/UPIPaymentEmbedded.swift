import SwiftUI

struct UPIPaymentEmbedded: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @State private var selectedAccount: Account?
    @State private var upiId = ""
    @State private var amount = ""
    @State private var remarks = ""
    @State private var showingScanner = false
    @State private var showingConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var errorCode: PaymentError?
    @State private var isProcessing = false
    
    private let quickAmounts: [Decimal] = [Decimal(100), Decimal(500), Decimal(1000), Decimal(2000)]
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                GlassCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Pay To")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        AccountPicker(selection: $selectedAccount, accounts: accountViewModel.accounts)
                        
                        HStack(spacing: 8) {
                            ModernTextField(
                                label: "UPI ID",
                                placeholder: "name@upi",
                                text: $upiId,
                                systemImage: "person.crop.circle",
                                keyboardType: .emailAddress
                            )
                            .textInputAutocapitalization(.none)
                            
                            Button(action: { showingScanner = true }) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.title3)
                                    .foregroundColor(Color.bankPrimary)
                                    .frame(width: 44, height: 44)
                                    .background(Color(UIColor.systemGroupedBackground))
                                    .cornerRadius(AppTheme.CornerRadius.pill)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel("Scan QR Code")
                        }
                    }
                    .padding()
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
                }
                .padding(.horizontal)
                
                ModernButton(
                    title: isProcessing ? "Processing..." : "Pay via UPI with Face ID",
                    systemImage: isProcessing ? nil : "faceid",
                    variant: isFormValid ? .filled : .glass
                ) {
                    initiateUPIPayment()
                }
                .disabled(!isFormValid || isProcessing)
                .padding(.horizontal)
                
                if let error = errorCode {
                    ErrorBanner(error: error)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingScanner) {
            UPCScannerView(upiId: $upiId)
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
        .alert("Confirm UPI Payment", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Authorize", role: .destructive) {
                requestBiometricAuth()
            }
        } message: {
            Text("Pay \(CurrencyFormatter.shared.string(from: Decimal(string: amount) ?? 0)) to \(upiId)?")
        }
    }
    
    private var isFormValid: Bool {
        guard let account = selectedAccount else { return false }
        guard let amountDecimal = Decimal(string: amount), amountDecimal > 0 else { return false }
        guard !upiId.isEmpty else { return false }
        guard isValidUPIId else { return false }
        guard Decimal(string: amountDecimal.description) ?? 0 <= account.availableBalance else { return false }
        return true
    }
    
    private var isValidUPIId: Bool {
        upiId.contains("@")
    }
    
    private func initiateUPIPayment() {
        if !isValidUPIId {
            errorCode = .invalidUPI
            errorMessage = "Please enter a valid UPI ID (e.g., name@upi)"
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        guard let amountDecimal = Decimal(string: amount), amountDecimal > 0 else {
            errorCode = .invalidAmount
            errorMessage = "Please enter a valid amount greater than zero."
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        guard let account = selectedAccount, amountDecimal <= account.availableBalance else {
            errorCode = .insufficientBalance
            errorMessage = "Insufficient balance. Available: \(selectedAccount?.formattedAvailableBalance ?? "0")"
            HapticFeedbackService.shared.errorOccurred()
            return
        }
        
        showingConfirmation = true
    }
    
    private func requestBiometricAuth() {
        guard authenticationService.canUseBiometrics else {
            errorCode = .authenticationFailed
            errorMessage = "Biometric authentication is required for UPI payments."
            HapticFeedbackService.shared.errorOccurred()
            showingError = true
            return
        }
        
        showingConfirmation = false
        
        authenticationService.authenticateWithBiometrics { success in
            DispatchQueue.main.async {
                if success {
                    processUPIPayment()
                } else {
                    errorCode = .authenticationFailed
                    errorMessage = "Authentication failed. Please try again."
                    HapticFeedbackService.shared.errorOccurred()
                    showingError = true
                }
            }
        }
    }
    
    private func processUPIPayment() {
        guard let amountDecimal = Decimal(string: amount) else { return }
        guard let account = selectedAccount else { return }
        
        isProcessing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            accountViewModel.addUPITransaction(upiId: upiId, amount: amountDecimal)
            isProcessing = false
            HapticFeedbackService.shared.success()
            errorMessage = "UPI payment of \(CurrencyFormatter.shared.string(from: amountDecimal)) to \(upiId) successful!"
            showingError = true
        }
    }
}