import SwiftUI
import Combine
import SwiftData

struct AccountOverviewView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var bannerStack = BannerStackManager.shared
    @State private var showUPITapPay = false
    @State private var showingError = false
    @State private var showAllTransactions = false
    @State private var showTransfer = false
    @State private var showBillPay = false
    @State private var showFixedDeposits = false
    @State private var showLoans = false
    /// Tracks the most recent transaction already seen, so a completed
    /// payment/transfer/bill-pay (from any sheet above) surfaces a banner
    /// here on Home exactly once — without each payment flow needing its
    /// own direct call into `BannerStackManager`.
    @State private var lastSeenTransactionId: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AppSpacing.lg) {
                    HeroHeaderView(greetingName: authenticationService.user?.firstName ?? "there")

                    DemoModeBanner()
                        .padding(.horizontal)

                    if accountViewModel.isLoading && accountViewModel.accounts.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.xl)
                    } else if !accountViewModel.accounts.isEmpty {
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

                            IntelligenceBriefingCard()
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
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.bankPrimary)
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
                            GlassCard {
                                VStack(spacing: 0) {
                                    ForEach(Array(transactionViewModel.recentTransactions.prefix(5).enumerated()), id: \.element.id) { index, transaction in
                                        ModernTransactionRow(transaction: transaction)
                                            .padding(.horizontal, AppSpacing.sm)
                                            .accessibilityElement(children: .combine)
                                            .transition(.opacity.combined(with: .move(edge: .leading)))
                                            .animation(
                                                AppTheme.Animation.entrance.delay(Double(index) * 0.03),
                                                value: transactionViewModel.recentTransactions.count
                                            )

                                        if index < min(4, transactionViewModel.recentTransactions.count - 1) {
                                            Divider()
                                                .padding(.leading, 62)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
                .adaptiveContentWidth(PlatformUI.dashboardMaxWidth)
            }
            .bankSoftScrollEdges()
            .navigationTitle("Home")
            .bankInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
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
        // Scoped to the NavigationStack itself, not the inner ScrollView --
        // .scrollContentBackground(.hidden) on a bare ScrollView doesn't
        // reliably clear its background inside a NavigationStack/TabView
        // hierarchy, so the ambient mesh background gets fully obscured.
        .transparentChrome()
        .overlay(alignment: .bottom) {
            BannerStackView(manager: bannerStack)
                .padding(.bottom, AppSpacing.sm)
                .allowsHitTesting(!bannerStack.items.isEmpty)
        }
        .onAppear {
            lastSeenTransactionId = transactionViewModel.recentTransactions.first?.id
        }
        .onChange(of: transactionViewModel.recentTransactions.first?.id) { _, newId in
            announceIfNewTransaction(newId)
        }
    }

    /// Fires a banner exactly once per genuinely new transaction — covers
    /// transfers, UPI payments, and bill pay alike, since all of them route
    /// through `transactionViewModel.loadAllTransactions()` on completion,
    /// which is what updates `recentTransactions.first`.
    private func announceIfNewTransaction(_ newId: String?) {
        guard let newId, newId != lastSeenTransactionId else { return }
        lastSeenTransactionId = newId
        guard let transaction = transactionViewModel.recentTransactions.first(where: { $0.id == newId }) else { return }

        bannerStack.push(
            BannerItem(
                title: transaction.isCredit ? "Money received" : "Payment sent",
                message: "\(transaction.formattedAmount) · \(transaction.transactionDescription)",
                icon: transaction.isCredit ? "arrow.down.circle.fill" : "checkmark.circle.fill",
                tint: transaction.isCredit ? .bankSuccess : .bankPrimary
            )
        )
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(greeting), \(greetingName)")
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("\(greeting), \(greetingName)")

                Text("Here's your financial overview")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Financial overview")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "building.columns.fill")
                .font(.title2)
                .foregroundStyle(Color.bankPrimary.opacity(0.35))
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

struct BalanceCard: View {
    let totalBalance: Decimal
    let availableBalance: Decimal
    var hideBalances: Bool = false
    var onToggleHide: (() -> Void)? = nil

    @State private var isTotalAnimating = false
    @State private var isAvailableAnimating = false

    private var totalText: String {
        hideBalances ? "••••••" : CurrencyFormatter.shared.string(from: totalBalance)
    }

    private var availableText: String {
        hideBalances ? "••••" : CurrencyFormatter.shared.string(from: availableBalance)
    }
    
    var body: some View {
        GlassCard(reactsToTilt: true, tint: Color.bankPrimary) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Total Balance", systemImage: "indianrupee.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)

                    Spacer()

                    Button {
                        onToggleHide?()
                    } label: {
                        Image(systemName: hideBalances ? "eye.slash.fill" : "eye.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.bankPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.bankPrimary.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(ScalePressButtonStyle())
                    .accessibilityLabel(hideBalances ? "Show balances" : "Hide balances")
                }

                // Ported from the "Transitions.dev — Number pop-in" CSS
                // snippet: each character animates in with a staggered
                // offset/opacity/blur pop instead of the plain fade
                // `.contentTransition(.numericText())` gave before.
                AnimatedDigitText(
                    text: totalText,
                    isAnimating: isTotalAnimating,
                    font: AppTheme.Typography.monospacedHero(),
                    color: .primary
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(hideBalances
                    ? "Total balance hidden"
                    : "Total balance: \(CurrencyFormatter.shared.string(from: totalBalance))")

                HStack {
                    Text("Available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AnimatedDigitText(
                        text: availableText,
                        isAnimating: isAvailableAnimating,
                        font: .caption.weight(.semibold).monospacedDigit(),
                        color: .secondary,
                        distance: 4,
                        stagger: 0.04,
                        blurRadius: 1
                    )
                    Spacer()
                }
            }
            .padding(AppSpacing.lg)
        }
        .onAppear { replay() }
        .onChange(of: totalText) { replay() }
    }

    /// Mirrors the CSS replay recipe: drop the "is-animating" state, wait a
    /// beat for the reset to commit, then turn it back on so the keyframes
    /// run again from their 0% state.
    private func replay() {
        isTotalAnimating = false
        isAvailableAnimating = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            isTotalAnimating = true
            isAvailableAnimating = true
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
                            VStack(spacing: 10) {
                                Image(systemName: action.systemImage)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(action.color)
                                    .frame(width: 52, height: 52)
                                    .glassCircle(tint: action.color)

                                Text(action.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 72)
                            }
                        }
                        .buttonStyle(ScalePressButtonStyle())
                        .bankHoverHighlight()
                    }
                }
                .padding(.horizontal, 2)
                .scrollTargetLayout()
            }
        }
        .bankSoftScrollEdges()
        .scrollTargetBehavior(.viewAligned)
        .mask(
            HStack(spacing: 0) {
                Color.black
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 28)
            }
        )
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
        .bankSoftScrollEdges()
    }
}

struct AccountCardCompact: View {
    let account: Account
    var hideBalances: Bool = false

    @State private var isAnimating = false

    private var balanceText: String {
        hideBalances ? "••••••" : account.formattedBalance
    }

    var body: some View {
        GlassCard(tint: Color.bankPrimary) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(account.accountType.rawValue)
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    Spacer()
                    Image(systemName: "building.columns")
                        .font(.caption)
                        .foregroundStyle(Color.bankPrimary.opacity(0.7))
                }

                Text(account.nickname ?? "Account")
                    .font(.headline)

                Text("•••• \(account.accountNumber.suffix(4))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.bankGroupedBackground, in: Capsule())

                Divider().opacity(0.5)

                HStack {
                    Text("Balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    AnimatedDigitText(
                        text: balanceText,
                        isAnimating: isAnimating,
                        font: .title3.weight(.bold).monospacedDigit(),
                        color: .primary,
                        distance: 6,
                        stagger: 0.05
                    )
                }
            }
            .padding(AppSpacing.lg)
        }
        .bankHoverHighlight(AppTheme.CornerRadius.card)
        .onAppear { replay() }
        .onChange(of: balanceText) { replay() }
    }

    private func replay() {
        isAnimating = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            isAnimating = true
        }
    }
}

struct IntelligenceBriefingCard: View {
    @EnvironmentObject var accountViewModel: AccountViewModel

    var body: some View {
        if let headline = accountViewModel.briefingHeadline {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Daily briefing")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(accountViewModel.healthScore)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.bankPrimary)
                        Text("/100")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(headline)
                        .font(.subheadline)
                    if let note = accountViewModel.cashFlowNote {
                        Text(note).font(.caption).foregroundStyle(.secondary)
                    }
                    if let rec = accountViewModel.recurringCandidates.first {
                        Text("Looks recurring: \(rec.payee) \(CurrencyFormatter.shared.string(from: rec.amount)) ×\(rec.occurrences)")
                            .font(.caption)
                    }
                    if let a = accountViewModel.anomalies.first {
                        Text("Anomaly: \(a.description) — \(a.reason)")
                            .font(.caption)
                            .foregroundStyle(Color.bankWarning)
                    }
                }
                .padding()
            }
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
            GlassCard(tint: Color.bankInsight) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.bankInsight, Color.bankPrimary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Insight")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(insight)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(AppSpacing.lg)
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
    @State private var disputeTargetId: String?

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
                    .swipeActions {
                        Button {
                            disputeTargetId = transaction.id
                        } label: {
                            Label("Dispute", systemImage: "exclamationmark.bubble")
                        }
                        .tint(.orange)
                    }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search transactions")
            .autocorrectionDisabled(true)
            .navigationTitle("All Transactions")
            .bankInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: Binding(
                get: { disputeTargetId != nil },
                set: { if !$0 { disputeTargetId = nil } }
            )) {
                if let id = disputeTargetId, let tx = transactions.first(where: { $0.id == id }) {
                    NavigationStack {
                        DisputeIntakeView(transaction: tx)
                    }
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
