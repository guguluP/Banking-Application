import SwiftUI
import SwiftData

struct FixedDepositsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @Query(sort: \FixedDeposit.startDate, order: .reverse) private var allDeposits: [FixedDeposit]
    @State private var showingOpenDeposit = false
    
    private var myDeposits: [FixedDeposit] {
        guard let userId = authenticationService.user?.id else { return [] }
        return allDeposits.filter { $0.userId == userId }
    }
    
    private var totalInvested: Decimal {
        myDeposits.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.principal }
    }
    
    private var totalMaturityValue: Decimal {
        myDeposits.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.maturityValue }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AppSpacing.lg) {
                    if !myDeposits.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("Total Invested")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(CurrencyFormatter.shared.string(from: totalInvested))
                                    .font(.title.bold())
                                
                                HStack {
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text("Maturing to \(CurrencyFormatter.shared.string(from: totalMaturityValue))")
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
                        title: "Open a New Fixed Deposit",
                        systemImage: "plus.circle.fill",
                        variant: .filled
                    ) {
                        showingOpenDeposit = true
                    }
                    .padding(.horizontal)
                    
                    if myDeposits.isEmpty {
                        VStack(spacing: AppSpacing.md) {
                            Image(systemName: "banknote")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                                .symbolRenderingMode(.hierarchical)
                            Text("No fixed deposits yet")
                                .font(.headline)
                            Text("Open one to start earning interest on a lump sum")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(myDeposits) { deposit in
                            FixedDepositCard(deposit: deposit)
                                .padding(.horizontal)
                        }
                    }
                    
                    Text("Rates shown are illustrative sample figures, not live bank rates.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
                .padding(.vertical)
            }
            .bankSoftScrollEdges()
            .navigationTitle("Fixed Deposits")
            .sheet(isPresented: $showingOpenDeposit) {
                OpenFixedDepositView()
            }
        }
        .swipeDownToDismiss()
    }
}

struct FixedDepositCard: View {
    let deposit: FixedDeposit
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(deposit.nickname)
                            .font(.headline)
                        Text("\(String(format: "%.2f", deposit.interestRate))% p.a. · \(deposit.tenureMonths) months")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    statusBadge
                }
                
                VStack(spacing: 6) {
                    ProgressView(value: deposit.progressFraction)
                        .tint(Color.bankPrimary)
                    
                    HStack {
                        Text(deposit.formattedPrincipal)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(deposit.formattedMaturityValue)
                            .font(.caption2.bold())
                            .foregroundColor(.green)
                    }
                }
                
                if deposit.status == .active {
                    Text(deposit.daysRemaining > 0 ? "\(deposit.daysRemaining) days to maturity" : "Matures today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
    
    private var statusBadge: some View {
        Text(deposit.status.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch deposit.status {
        case .active: return Color.bankPrimary
        case .matured: return .green
        case .closed: return .secondary
        }
    }
}

struct OpenFixedDepositView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var accountViewModel: AccountViewModel
    @StateObject private var viewModel = FixedDepositViewModel()
    @State private var selectedSourceAccount: Account?
    @FocusState private var isPrincipalFocused: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Deposit Details", systemImage: "banknote.fill")
                                .font(.headline)
                            
                            ModernTextField(
                                label: "Nickname",
                                placeholder: "e.g. Emergency Fund",
                                text: $viewModel.nickname,
                                systemImage: "tag.fill"
                            )
                            
                            ModernTextField(
                                label: "Amount",
                                placeholder: "Minimum ₹1,000",
                                text: $viewModel.principalText,
                                isValid: viewModel.principalText.isEmpty || viewModel.isMinimumMet,
                                errorMessage: "Minimum deposit is ₹1,000",
                                systemImage: "indianrupeesign.circle",
                                keyboardType: .decimalPad
                            )
                            .focused($isPrincipalFocused)
                            
                            Text("From Account")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            AccountPicker(selection: $selectedSourceAccount, accounts: accountViewModel.accounts.filter { $0.accountType != .credit })
                        }
                        .padding()
                    }
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Tenure", systemImage: "calendar")
                                .font(.headline)
                            
                            Picker("Tenure", selection: $viewModel.tenureMonths) {
                                ForEach(FDRateCard.availableTenuresMonths, id: \.self) { months in
                                    Text(months < 12 ? "\(months) mo" : "\(months / 12) yr").tag(months)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Toggle("Senior Citizen", isOn: $viewModel.isSeniorCitizen)
                                .toggleStyle(SwitchToggleStyle(tint: Color.bankPrimary))
                            
                            Text(viewModel.tenureLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                Label("Projected Returns", systemImage: "chart.line.uptrend.xyaxis")
                                    .font(.headline)
                                Spacer()
                                Text("\(String(format: "%.2f", viewModel.currentRate))% p.a.")
                                    .font(.caption.bold())
                                    .foregroundColor(Color.bankPrimary)
                            }
                            
                            if let maturityValue = viewModel.projectedMaturityValue,
                               let interest = viewModel.projectedInterest {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("At Maturity")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(CurrencyFormatter.shared.string(from: maturityValue))
                                            .font(.title3.bold())
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Interest Earned")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("+\(CurrencyFormatter.shared.string(from: interest))")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.green)
                                    }
                                }
                            } else {
                                Text("Enter an amount to see projected returns")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }
                    
                    if let error = viewModel.error {
                        ErrorBannerModern(error: error)
                    }
                    
                    ModernButton(
                        title: "Open Deposit",
                        systemImage: "checkmark.circle.fill",
                        variant: .filled
                    ) {
                        open()
                    }
                    .disabled(!viewModel.canOpen || selectedSourceAccount == nil)
                    .opacity((viewModel.canOpen && selectedSourceAccount != nil) ? 1 : 0.5)
                }
                .padding()
            }
            .bankSoftScrollEdges()
            .navigationTitle("New Fixed Deposit")
            .onAppear {
                if selectedSourceAccount == nil {
                    selectedSourceAccount = accountViewModel.accounts.first { $0.isPrimary && $0.accountType != .credit }
                        ?? accountViewModel.accounts.first { $0.accountType != .credit }
                }
            }
        }
        .swipeDownToDismiss()
    }
    
    private func open() {
        guard let account = selectedSourceAccount else { return }
        if viewModel.openDeposit(from: account, in: modelContext) {
            HapticFeedbackService.shared.success()
            dismiss()
        } else {
            HapticFeedbackService.shared.errorOccurred()
        }
    }
}

struct FixedDepositsView_Previews: PreviewProvider {
    static var previews: some View {
        FixedDepositsView()
    }
}
