import SwiftUI
import Combine
import SwiftData

struct AccountOverviewView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @ObservedObject private var settings = AppSettings.shared
    @State private var showUPITapPay = false
    @State private var showingError = false
    @State private var showAllTransactions = false
    @State private var showTransfer = false
    @State private var showBillPay = false
    @State private var showFixedDeposits = false
    @State private var showLoans = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AppSpacing.lg) {
                    HeroHeaderView(greetingName: authenticationService.user?.firstName ?? "there")

                    DemoModeBanner()
                        .padding(.horizontal)
                    
                    if !accountViewModel.accounts.isEmpty {
                        VStack(spacing: AppSpacing.md) {
                            BalanceCard(
                                totalBalance: accountViewModel.totalBalance,
                                availableBalance: accountViewModel.totalAvailableBalance,
                                hideBalances: settings.hideBalances,
                                onToggleHide: {
                                    settings.hideBalances.toggle()
                                    HapticFeedbackService.shared.lightImpact()
                                }
                            )
                            
                            QuickActionsView(showUPITapPay: $showUPITapPay, showTransfer: $showTransfer, showBillPay: $showBillPay, showFixedDeposits: $showFixedDeposits, showLoans: $showLoans)

                            AIInsightCard()

                            SpendingChartCard(data: accountViewModel.weeklySpending)
                            CategoryBreakdownChartCard(categories: accountViewModel.categoryBreakdown)
                        }
                        .padding(.horizontal)
                    } else {
                        ErrorStateView(
                            imageName: "exclamationmark.triangle",
                            title: "No Accounts Found",
                            message: "No demo accounts are available yet. Tap Retry to reload the local sample data.",
                            actionTitle: "Retry",
                            action: {
                                accountViewModel.loadAccounts()
                            }
                        )
                        .padding()
                    }
                    
                    if !accountViewModel.accounts.isEmpty {
                        AccountsCarousel(accounts: accountViewModel.accounts, hideBalances: settings.hideBalances)
                    }
                    
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack {
                            Text("Recent Transactions")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            
                            Spacer()
                            
                            Button("See All") {
                                showAllTransactions = true
                            }
                            .font(.subheadline)
                            .foregroundColor(Color.bankPrimary)
                            .accessibilityLabel("See all transactions")
                        }
                        .padding(.horizontal)
                        
                        if transactionViewModel.recentTransactions.isEmpty {
                            ErrorStateView(
                                imageName: "doc.text",
                                title: "No Transactions",
                                message: "No recent transactions to display.",
                                actionTitle: "Refresh",
                                action: {
                                    transactionViewModel.loadAllTransactions()
                                }
                            )
                            .padding(.vertical)
                        } else {
                            ForEach(Array(transactionViewModel.recentTransactions.prefix(5).enumerated()), id: \.element.id) { index, transaction in
                                ModernTransactionRow(transaction: transaction)
                                    .padding(.horizontal)
                                    .accessibilityElement(children: .combine)
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                                    .animation(.spring(response: 0.4, dampingFraction: 0.85).delay(Double(index) * 0.03), value: transactionViewModel.recentTransactions.count)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showUPITapPay = true }) {
                        Image(systemName: "qrcode.viewfinder")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Scan QR Code")
                }
            }
            .refreshable {
                accountViewModel.loadAccounts()
                transactionViewModel.loadAllTransactions()
                await accountViewModel.refreshAIInsight()
            }
            .task {
                await accountViewModel.refreshAIInsight()
            }
            .sheet(isPresented: $showUPITapPay) {
                UPIPaymentView()
            }
            .sheet(isPresented: $showTransfer) {
                TransferView()
            }
            .sheet(isPresented: $showBillPay) {
                BillPayView()
            }
            .sheet(isPresented: $showFixedDeposits) {
                FixedDepositsView()
            }
            .sheet(isPresented: $showLoans) {
                LoanTrackerView()
            }
            .sheet(isPresented: $showAllTransactions) {
                AllTransactionsView(transactions: transactionViewModel.recentTransactions)
            }
            .accessibilityElement(children: .contain)
        }
    }
}

struct HeroHeaderView: View {
    let greetingName: String
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning" }
        else if hour < 17 { return "Good Afternoon" }
        else { return "Good Evening" }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting), \(greetingName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("\(greeting), \(greetingName)")
                
                Text("Here's your financial overview")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Financial overview")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
    }
}

struct BalanceCard: View {
    let totalBalance: Decimal
    let availableBalance: Decimal
    var hideBalances: Bool = false
    var onToggleHide: (() -> Void)? = nil

    private var totalText: String {
        hideBalances ? "••••••" : CurrencyFormatter.shared.string(from: totalBalance)
    }

    private var availableText: String {
        hideBalances ? "••••" : CurrencyFormatter.shared.string(from: availableBalance)
    }
    
    var body: some View {
        GlassCard(reactsToTilt: true) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total Balance")
                        .font(.headline)
                    
                    Spacer()

                    Button {
                        onToggleHide?()
                    } label: {
                        Image(systemName: hideBalances ? "eye.slash.fill" : "eye.fill")
                            .font(.subheadline)
                            .foregroundColor(Color.bankPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(hideBalances ? "Show balances" : "Hide balances")
                }
                
                Text(totalText)
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                    .accessibilityLabel(hideBalances
                        ? "Total balance hidden"
                        : "Total balance: \(CurrencyFormatter.shared.string(from: totalBalance))")
                
                Text("Available: \(availableText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .padding()
        }
    }
}

struct QuickActionsView: View {
    @Binding var showUPITapPay: Bool
    @Binding var showTransfer: Bool
    @Binding var showBillPay: Bool
    @Binding var showFixedDeposits: Bool
    @Binding var showLoans: Bool
    
    let quickActions: [QuickAction] = [
        QuickAction(title: "Scan & Pay", systemImage: "qrcode.viewfinder", color: .blue),
        QuickAction(title: "Send Money", systemImage: "paperplane.fill", color: .green),
        QuickAction(title: "Pay Bills", systemImage: "doc.text.fill", color: .orange),
        QuickAction(title: "Fixed Deposits", systemImage: "banknote.fill", color: .purple),
        QuickAction(title: "Loans", systemImage: "building.columns.fill", color: .indigo)
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LiquidGlass.container(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(quickActions) { action in
                        Button(action: {
                            HapticFeedbackService.shared.lightImpact()
                            switch action.title {
                            case "Scan & Pay":
                                showUPITapPay = true
                            case "Send Money":
                                showTransfer = true
                            case "Pay Bills":
                                showBillPay = true
                            case "Fixed Deposits":
                                showFixedDeposits = true
                            case "Loans":
                                showLoans = true
                            default:
                                break
                            }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: action.systemImage)
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .glassControl(cornerRadius: AppTheme.CornerRadius.pill, tint: action.color)
                                
                                Text(action.title)
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let color: Color
}

struct AccountsCarousel: View {
    let accounts: [Account]
    var hideBalances: Bool = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(accounts) { account in
                    AccountCardCompact(account: account, hideBalances: hideBalances)
                        .frame(width: 280)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct AccountCardCompact: View {
    let account: Account
    var hideBalances: Bool = false
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(account.accountType.rawValue)
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                
                Text(account.nickname ?? "Account")
                    .font(.headline)
                
                Text("•••• \(account.accountNumber.suffix(4))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                    .background(Color.secondary.opacity(0.2))
                
                HStack {
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(hideBalances ? "••••••" : account.formattedBalance)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
            }
            .padding()
        }
    }
}

/// A card that shows an on-device, Apple Intelligence-generated summary of the
/// week's spending. Hides itself entirely if the feature is unavailable or
/// hasn't produced anything yet, rather than showing an empty or broken state.
struct AIInsightCard: View {
    @EnvironmentObject var accountViewModel: AccountViewModel

    var body: some View {
        if accountViewModel.isGeneratingInsight {
            GlassCard {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                    Text("Thinking about your spending…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
            }
            .transition(.opacity)
        } else if let insight = accountViewModel.aiInsight, !insight.isEmpty {
            GlassCard {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Insight")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text(insight)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding()
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            .accessibilityElement(children: .combine)
        }
    }
}

struct AllTransactionsView: View {
    let transactions: [Transaction]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [Transaction] {
        guard !searchText.isEmpty else { return transactions }
        return transactions.filter {
            $0.description.localizedCaseInsensitiveContains(searchText) ||
            ($0.category ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { transaction in
                ModernTransactionRow(transaction: transaction)
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search transactions")
            .autocorrectionDisabled(true)
            .navigationTitle("All Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AccountOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.preview
        let context = container.mainContext
        let transactionViewModel = TransactionViewModel(modelContext: context)
        let accountViewModel = AccountViewModel(modelContext: context, transactionViewModel: transactionViewModel)
        return NavigationStack {
            AccountOverviewView()
                .environmentObject(accountViewModel)
                .environmentObject(transactionViewModel)
                .environmentObject(AuthenticationService())
        }
        .modelContainer(container)
    }
}
