import SwiftUI

struct AccountOverviewView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @State private var showUPITapPay = false
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AppSpacing.lg) {
                    HeroHeaderView(greetingName: "John")
                    
                    if !accountViewModel.accounts.isEmpty {
                        VStack(spacing: AppSpacing.md) {
                            BalanceCard(totalBalance: accountViewModel.totalBalance, availableBalance: accountViewModel.totalAvailableBalance)
                            
                            QuickActionsView(showUPITapPay: $showUPITapPay)
                            
                            SpendingChartCard(data: accountViewModel.weeklySpending)
                            CategoryBreakdownChartCard(categories: accountViewModel.categoryBreakdown)
                        }
                        .padding(.horizontal)
                    } else {
                        ErrorStateView(
                            imageName: "exclamationmark.triangle",
                            title: "No Accounts Found",
                            message: "Unable to load your accounts. Please check your connection and try again.",
                            actionTitle: "Retry",
                            action: {
                                accountViewModel.loadAccounts()
                            }
                        )
                        .padding()
                    }
                    
                    if !accountViewModel.accounts.isEmpty {
                        AccountsCarousel(accounts: accountViewModel.accounts)
                    }
                    
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack {
                            Text("Recent Transactions")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            
                            Spacer()
                            
                            Button("See All") {
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
                                    transactionViewModel.loadTransactions(for: "acc_001")
                                }
                            )
                            .padding(.vertical)
                        } else {
                            ForEach(transactionViewModel.recentTransactions.prefix(5)) { transaction in
                                ModernTransactionRow(transaction: transaction)
                                    .padding(.horizontal)
                                    .accessibilityElement(children: .combine)
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
                transactionViewModel.loadTransactions(for: "acc_001")
            }
            .sheet(isPresented: $showUPITapPay) {
                UPIPaymentView()
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
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total Balance")
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                Text(CurrencyFormatter.shared.string(from: totalBalance))
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.primary)
                    .accessibilityLabel("Total balance: \(CurrencyFormatter.shared.string(from: totalBalance))")
                
                Text("Available: \(CurrencyFormatter.shared.string(from: availableBalance))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

struct QuickActionsView: View {
    @Binding var showUPITapPay: Bool
    
    let quickActions: [QuickAction] = [
        QuickAction(title: "Scan & Pay", systemImage: "qrcode.viewfinder", color: .blue),
        QuickAction(title: "Send Money", systemImage: "paperplane.fill", color: .green),
        QuickAction(title: "Pay Bills", systemImage: "doc.text.fill", color: .orange)
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.md) {
                ForEach(quickActions) { action in
                    Button(action: {
                        HapticFeedbackService.shared.lightImpact()
                        if action.title == "Scan & Pay" {
                            showUPITapPay = true
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: action.systemImage)
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(action.color)
                                .cornerRadius(AppTheme.CornerRadius.pill)
                            
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

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let color: Color
}

struct AccountsCarousel: View {
    let accounts: [Account]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(accounts) { account in
                    AccountCardCompact(account: account)
                        .frame(width: 280)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct AccountCardCompact: View {
    let account: Account
    
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
                    Text(account.formattedBalance)
                        .font(.title3.weight(.bold))
                }
            }
            .padding()
        }
    }
}

struct AccountOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        let transactionViewModel = TransactionViewModel()
        let accountViewModel = AccountViewModel(transactionViewModel: transactionViewModel)
        return NavigationStack {
            AccountOverviewView()
                .environmentObject(accountViewModel)
                .environmentObject(transactionViewModel)
        }
    }
}