import SwiftUI
import SwiftData

struct AddBeneficiaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authenticationService: AuthenticationService
    @StateObject private var viewModel = BeneficiaryViewModel()
    @FocusState private var focusedField: Field?
    
    var onSaved: (() -> Void)? = nil
    
    enum Field {
        case nickname, accountNumber, confirmAccountNumber, ifsc
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Payee Details", systemImage: "person.fill")
                                .font(.headline)
                            
                            ModernTextField(
                                label: "Nickname",
                                placeholder: "e.g. Landlord, Mom, Rent",
                                text: $viewModel.nickname,
                                systemImage: "tag.fill"
                            )
                            .focused($focusedField, equals: .nickname)
                            
                            ModernTextField(
                                label: "Account Number",
                                placeholder: "8–18 digit account number",
                                text: $viewModel.accountNumber,
                                isValid: viewModel.accountNumber.isEmpty || viewModel.isAccountNumberValid,
                                errorMessage: "Enter a valid 8–18 digit account number",
                                systemImage: "number",
                                keyboardType: .numberPad
                            )
                            .focused($focusedField, equals: .accountNumber)
                            
                            ModernTextField(
                                label: "Confirm Account Number",
                                placeholder: "Re-enter account number",
                                text: $viewModel.confirmAccountNumber,
                                isValid: viewModel.confirmAccountNumber.isEmpty || viewModel.accountNumbersMatch,
                                errorMessage: "Account numbers don't match",
                                systemImage: "checkmark.circle",
                                keyboardType: .numberPad
                            )
                            .focused($focusedField, equals: .confirmAccountNumber)
                        }
                        .padding()
                    }
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Bank Details", systemImage: "building.columns.fill")
                                .font(.headline)
                            
                            ModernTextField(
                                label: "IFSC Code",
                                placeholder: "e.g. PUNB0123456",
                                text: $viewModel.ifscCode,
                                isValid: viewModel.ifscCode.isEmpty || viewModel.isIFSCFormatValid,
                                errorMessage: "IFSC should be 11 characters, like PUNB0123456",
                                systemImage: "building.columns"
                            )
                            .focused($focusedField, equals: .ifsc)
                            .textInputAutocapitalization(.characters)
                            .onChange(of: viewModel.ifscCode) { _, newValue in
                                viewModel.ifscCode = newValue.uppercased()
                                if newValue.count == 11 {
                                    focusedField = nil
                                    Task { await viewModel.lookupIFSC() }
                                } else {
                                    viewModel.resolvedBranch = nil
                                    viewModel.lookupError = nil
                                }
                            }
                            
                            ifscStatusView
                        }
                        .padding()
                    }
                    
                    if let error = viewModel.error {
                        ErrorBannerModern(error: error)
                    }
                    
                    ModernButton(
                        title: "Save Payee",
                        systemImage: "checkmark.circle.fill",
                        variant: .filled
                    ) {
                        save()
                    }
                    .disabled(!viewModel.canSave)
                    .opacity(viewModel.canSave ? 1 : 0.5)
                    .padding(.top, AppSpacing.sm)
                }
                .padding()
            }
            .navigationTitle("Add Payee")
        }
        .swipeDownToDismiss()
    }
    
    @ViewBuilder
    private var ifscStatusView: some View {
        if viewModel.isLookingUp {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Verifying branch…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else if let branch = viewModel.resolvedBranch {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(branch.bank)
                        .font(.caption.bold())
                    Text(branch.branch)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let city = branch.city, let state = branch.state {
                        Text("\(city), \(state)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        } else if let lookupError = viewModel.lookupError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(lookupError)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func save() {
        guard let userId = authenticationService.user?.id else { return }
        if viewModel.saveBeneficiary(userId: userId, in: modelContext) {
            HapticFeedbackService.shared.success()
            onSaved?()
            dismiss()
        } else {
            HapticFeedbackService.shared.errorOccurred()
        }
    }
}

struct AddBeneficiaryView_Previews: PreviewProvider {
    static var previews: some View {
        AddBeneficiaryView()
    }
}
