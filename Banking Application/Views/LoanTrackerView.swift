import SwiftUI
import SwiftData

struct LoanTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @Query(sort: \Loan.startDate, order: .reverse) private var allLoans: [Loan]
    @State private var showingApply = false
    
    private var myLoans: [Loan] {
        guard let userId = authenticationService.user?.id else { return [] }
        return allLoans.filter { $0.userId == userId }
    }
    
    private var totalOutstanding: Decimal {
        myLoans.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.outstandingPrincipal }
    }
    
    private var totalMonthlyEMI: Decimal {
        myLoans.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.emiAmount }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AppSpacing.lg) {
                    if !myLoans.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("Total Outstanding")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(CurrencyFormatter.shared.string(from: totalOutstanding))
                                    .font(.title.bold())
                                
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(CurrencyFormatter.shared.string(from: totalMonthlyEMI))/month across all loans")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                    }
                    
                    ModernButton(
                        title: "Apply for a Loan",
                        systemImage: "plus.circle.fill",
                        variant: .filled
                    ) {
                        showingApply = true
                    }
                    .padding(.horizontal)
                    
                    if myLoans.isEmpty {
                        VStack(spacing: AppSpacing.md) {
                            Image(systemName: "banknote")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                                .symbolRenderingMode(.hierarchical)
                            Text("No loans yet")
                                .font(.headline)
                            Text("Personal, home, auto, or education — apply and track EMIs here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(myLoans) { loan in
                            NavigationLink(destination: LoanDetailView(loan: loan)) {
                                LoanCard(loan: loan)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                    
                    Text("Rates shown are illustrative sample figures, not live lending rates.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
                .padding(.vertical)
            }
            .bankSoftScrollEdges()
            .navigationTitle("Loans")
            .sheet(isPresented: $showingApply) {
                ApplyForLoanView()
            }
        }
        .swipeDownToDismiss()
    }
}

struct LoanCard: View {
    let loan: Loan
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: loan.loanType.systemImage)
                        .foregroundColor(Color.bankPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loan.nickname)
                            .font(.headline)
                        Text("\(loan.loanType.rawValue) · \(String(format: "%.2f", loan.interestRate))% p.a.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if loan.status != .active {
                        Text(loan.status.rawValue)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.15))
                            .foregroundColor(statusColor)
                            .clipShape(Capsule())
                    }
                }
                
                ProgressView(value: loan.progressFraction)
                    .tint(Color.bankPrimary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Outstanding")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(loan.formattedOutstanding)
                            .font(.subheadline.bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("EMI")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(loan.formattedEMI)
                            .font(.subheadline.bold())
                    }
                }
                
                if loan.status == .active {
                    Text("\(loan.remainingEMIs) EMIs remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }

    /// Closed (paid off on schedule) reads as a success; foreclosed (paid
    /// off early, but not the normal path) reads as neutral/informational
    /// rather than implying anything is wrong.
    private var statusColor: Color {
        switch loan.status {
        case .active: return Color.bankPrimary
        case .closed: return .green
        case .foreclosed: return .secondary
        }
    }
}

struct LoanDetailView: View {
    @Bindable var loan: Loan
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var accountViewModel: AccountViewModel
    @State private var selectedAccount: Account?
    @State private var showingPrepaySheet = false
    @State private var prepayAmountText = ""
    @StateObject private var viewModel = LoanViewModel()
    
    private var sourceAccount: Account? {
        accountViewModel.accounts.first { $0.id == loan.disbursementAccountId } ?? selectedAccount
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg) {
                GlassCard {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: loan.loanType.systemImage)
                            .font(.system(size: 30))
                            .foregroundColor(Color.bankPrimary)
                        Text(loan.nickname)
                            .font(.title3.bold())
                        Text(loan.loanType.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider().padding(.vertical, 4)
                        
                        HStack {
                            statColumn(title: "Outstanding", value: loan.formattedOutstanding)
                            Divider().frame(height: 30)
                            statColumn(title: "EMI", value: loan.formattedEMI)
                            Divider().frame(height: 30)
                            statColumn(title: "Remaining", value: "\(loan.remainingEMIs) mo")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .padding(.horizontal)
                
                if loan.status == .active, let account = sourceAccount {
                    HStack(spacing: AppSpacing.md) {
                        ModernButton(title: "Pay EMI", systemImage: "checkmark.circle.fill", variant: .filled) {
                            _ = viewModel.payEMI(for: loan, from: account, in: modelContext)
                            HapticFeedbackService.shared.success()
                        }
                        ModernButton(title: "Prepay", systemImage: "arrow.down.circle.fill", variant: .outlined) {
                            showingPrepaySheet = true
                        }
                    }
                    .padding(.horizontal)
                    
                    if let error = viewModel.error {
                        ErrorBannerModern(error: error)
                            .padding(.horizontal)
                    }
                    
                    let impact = LoanCalculator.prepaymentImpact(
                        outstandingPrincipal: loan.outstandingPrincipal,
                        annualRatePercent: loan.interestRate,
                        currentEMI: loan.emiAmount,
                        prepaymentAmount: min(loan.emiAmount * 6, loan.outstandingPrincipal)
                    )
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Prepayment tip", systemImage: "lightbulb.fill")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                            Text("Prepaying \(CurrencyFormatter.shared.string(from: min(loan.emiAmount * 6, loan.outstandingPrincipal))) now could save roughly \(CurrencyFormatter.shared.string(from: impact.interestSaved)) in interest and \(max(0, loan.remainingEMIs - impact.newRemainingMonths)) months off the tenure.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .bankSoftScrollEdges()
        .navigationTitle("Loan Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPrepaySheet) {
            PrepayLoanView(loan: loan, sourceAccount: sourceAccount)
        }
    }
    
    private func statColumn(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PrepayLoanView: View {
    @Bindable var loan: Loan
    let sourceAccount: Account?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = LoanViewModel()
    @State private var amountText = ""
    
    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ""))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                GlassCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Prepay \(loan.nickname)")
                            .font(.headline)
                        Text("Outstanding: \(loan.formattedOutstanding)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ModernTextField(
                            label: "Prepayment Amount",
                            placeholder: "Amount to prepay",
                            text: $amountText,
                            systemImage: "indianrupeesign.circle",
                            keyboardType: .decimalPad
                        )
                        
                        if let amount, sourceAccount != nil, amount > 0, amount <= loan.outstandingPrincipal {
                            let impact = LoanCalculator.prepaymentImpact(
                                outstandingPrincipal: loan.outstandingPrincipal,
                                annualRatePercent: loan.interestRate,
                                currentEMI: loan.emiAmount,
                                prepaymentAmount: amount
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Estimated interest saved: \(CurrencyFormatter.shared.string(from: impact.interestSaved))")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("New remaining tenure: \(impact.newRemainingMonths) months")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                if let error = viewModel.error {
                    ErrorBannerModern(error: error)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                ModernButton(title: "Confirm Prepayment", systemImage: "checkmark.circle.fill", variant: .filled) {
                    guard let amount, let account = sourceAccount else { return }
                    if viewModel.prepay(amount, for: loan, from: account, in: modelContext) {
                        HapticFeedbackService.shared.success()
                        dismiss()
                    } else {
                        HapticFeedbackService.shared.errorOccurred()
                    }
                }
                .disabled(amount == nil || amount == 0 || sourceAccount == nil)
                .opacity((amount != nil && amount != 0 && sourceAccount != nil) ? 1 : 0.5)
                .padding(.horizontal)
            }
            .padding(.top)
            .navigationTitle("Prepay Loan")
        }
        .swipeDownToDismiss()
    }
}

struct ApplyForLoanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var accountViewModel: AccountViewModel
    @StateObject private var viewModel = LoanViewModel()
    @State private var selectedAccount: Account?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Loan Type", systemImage: "list.bullet")
                                .font(.headline)
                            
                            Picker("Loan Type", selection: $viewModel.loanType) {
                                ForEach(LoanType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding()
                    }
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Loan Details", systemImage: "doc.text.fill")
                                .font(.headline)
                            
                            ModernTextField(
                                label: "Nickname",
                                placeholder: "e.g. New Car",
                                text: $viewModel.nickname,
                                systemImage: "tag.fill"
                            )
                            
                            ModernTextField(
                                label: "Loan Amount",
                                placeholder: "Minimum ₹10,000",
                                text: $viewModel.principalText,
                                isValid: viewModel.principalText.isEmpty || viewModel.isMinimumMet,
                                errorMessage: "Minimum loan amount is ₹10,000",
                                systemImage: "indianrupeesign.circle",
                                keyboardType: .decimalPad
                            )
                            
                            Text("Tenure: \(viewModel.tenureMonths) months")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: Binding(
                                get: { Double(viewModel.tenureMonths) },
                                set: { viewModel.tenureMonths = Int($0) }
                            ), in: 6...84, step: 6)
                            .tint(Color.bankPrimary)
                            
                            Text("Disburse To")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            AccountPicker(selection: $selectedAccount, accounts: accountViewModel.accounts.filter { $0.accountType != .credit })
                        }
                        .padding()
                    }
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                Label("Estimated EMI", systemImage: "calendar.badge.clock")
                                    .font(.headline)
                                Spacer()
                                Text("\(String(format: "%.2f", viewModel.currentRate))% p.a.")
                                    .font(.caption.bold())
                                    .foregroundColor(Color.bankPrimary)
                            }
                            
                            if let emi = viewModel.projectedEMI, let interest = viewModel.projectedTotalInterest {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Monthly EMI")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(CurrencyFormatter.shared.string(from: emi))
                                            .font(.title3.bold())
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Total Interest")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(CurrencyFormatter.shared.string(from: interest))
                                            .font(.subheadline.bold())
                                            .foregroundColor(.orange)
                                    }
                                }
                            } else {
                                Text("Enter an amount to see your estimated EMI")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }
                    
                    if let error = viewModel.error {
                        ErrorBannerModern(error: error)
                    }
                    
                    ModernButton(title: "Apply for Loan", systemImage: "checkmark.circle.fill", variant: .filled) {
                        guard let account = selectedAccount else { return }
                        if viewModel.applyForLoan(disbursingTo: account, in: modelContext) {
                            HapticFeedbackService.shared.success()
                            dismiss()
                        } else {
                            HapticFeedbackService.shared.errorOccurred()
                        }
                    }
                    .disabled(!viewModel.canApply || selectedAccount == nil)
                    .opacity((viewModel.canApply && selectedAccount != nil) ? 1 : 0.5)
                }
                .padding()
            }
            .bankSoftScrollEdges()
            .navigationTitle("Apply for a Loan")
            .onAppear {
                if selectedAccount == nil {
                    selectedAccount = accountViewModel.accounts.first { $0.isPrimary && $0.accountType != .credit }
                        ?? accountViewModel.accounts.first { $0.accountType != .credit }
                }
            }
        }
        .swipeDownToDismiss()
    }
}

struct LoanTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        LoanTrackerView()
    }
}
