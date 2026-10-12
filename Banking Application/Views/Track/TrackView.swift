import SwiftUI
import SwiftData

/// Root of the "Track" tab — a Windfall-style expense tracker layered on
/// top of the app's real accounts. Entries created here are real
/// `Transaction`s (see `ExpenseTrackerViewModel.addExpense`), so they debit
/// the chosen account exactly like a payment or transfer would; this view
/// is the home base for browsing, adding, and understanding that spending.
struct TrackView: View {
    @Environment(AccountViewModel.self) var accountViewModel
    @Environment(TransactionViewModel.self) var transactionViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var tracker: ExpenseTrackerViewModel

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showingQuickAdd = false
    @State private var showingPrivacy = false
    @State private var section: TrackSection? = .overview

    init(accountViewModel: AccountViewModel, transactionViewModel: TransactionViewModel, modelContext: ModelContext) {
        _tracker = State(initialValue: ExpenseTrackerViewModel(
            modelContext: modelContext,
            accountViewModel: accountViewModel,
            transactionViewModel: transactionViewModel
        ))
    }

    var body: some View {
        Group {
            if sizeClass == .compact {
                NavigationStack { trackRoot }
            } else {
                NavigationSplitView {
                    List(TrackSection.allCases, selection: $section) { item in
                        Label(item.title, systemImage: item.symbol)
                            .tag(item)
                    }
                    .navigationTitle("Track")
                } detail: {
                    NavigationStack {
                        sectionDetail(section ?? .overview)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingQuickAdd = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .accessibilityLabel("Add Expense")
                    }
                }
            }
        }
        .environment(tracker)
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddExpenseView()
                .environment(accountViewModel)
                .environment(tracker)
        }
        .sheet(isPresented: $showingPrivacy) {
            ExpenseTrackerPrivacyView()
                .environment(tracker)
        }
    }

    private var trackRoot: some View {
        Group {
            if !tracker.hasLoadedOnce {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tracker.expenseEntries.isEmpty {
                firstRunEmptyState
            } else {
                dashboard
            }
        }
        .navigationTitle("Track")
        .bankInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingQuickAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Add Expense")
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingPrivacy = true
                } label: {
                    Label("Privacy & Data", systemImage: "lock.shield")
                }
            }
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddExpenseView()
                .environment(accountViewModel)
                .environment(tracker)
        }
        .sheet(isPresented: $showingPrivacy) {
            ExpenseTrackerPrivacyView()
                .environment(tracker)
        }
        .transparentChrome()
    }

    private var dashboard: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Text("Track")
                    .font(.largeTitle.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, AppSpacing.sm)
                    .accessibilityAddTraits(.isHeader)

                privacyBanner

                NavigationLink {
                    ExpenseAnalyticsDashboardView(tracker: tracker)
                        .environment(tracker)
                } label: {
                    monthSummaryCard
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                insightCards

                VStack(spacing: AppSpacing.md) {
                    NavigationLink {
                        ExpenseLedgerView().environment(tracker)
                    } label: {
                        trackMenuRow(icon: "list.bullet.rectangle", title: "Ledger", subtitle: "\(tracker.expenseEntries.count) expenses logged")
                    }

                    NavigationLink {
                        BudgetsView().environment(tracker)
                    } label: {
                        trackMenuRow(icon: "chart.pie.fill", title: "Budgets", subtitle: "\(tracker.budgets.count) active budgets")
                    }

                    NavigationLink {
                        EnvelopesView()
                    } label: {
                        trackMenuRow(icon: "envelope.fill", title: "Envelopes", subtitle: "Named spending buckets")
                    }

                    NavigationLink {
                        SavingsGoalsView()
                    } label: {
                        trackMenuRow(icon: "flag.fill", title: "Savings goals", subtitle: "Targets tied to FDs")
                    }

                    NavigationLink {
                        BillCalendarView()
                    } label: {
                        trackMenuRow(icon: "calendar", title: "Bill calendar", subtitle: "EMIs, bills, FD maturities")
                    }

                    NavigationLink {
                        NetWorthView()
                    } label: {
                        trackMenuRow(icon: "chart.line.uptrend.xyaxis", title: "Net worth", subtitle: "Accounts + FDs − loans")
                    }

                    NavigationLink {
                        ImportReviewQueueView()
                    } label: {
                        trackMenuRow(icon: "tray.full", title: "Review imports", subtitle: "SMS and Account Aggregator")
                    }

                    NavigationLink {
                        SMSImportGuideView()
                    } label: {
                        trackMenuRow(icon: "message", title: "Bank SMS", subtitle: "Captured automatically")
                    }

                    NavigationLink {
                        AggregatorConsentView()
                    } label: {
                        trackMenuRow(icon: "link", title: "Account Aggregator", subtitle: "Sandbox consent and revoke")
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .bankSoftScrollEdges()
    }

    /// A lightweight preview of this month's spending, tappable through to
    /// the full `ExpenseAnalyticsDashboardView` — kept separate from that
    /// view (rather than embedding it directly) so this card isn't itself
    /// scrollable/interactive content nested inside a `NavigationLink`.
    private var monthSummaryCard: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spent This Month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.shared.string(from: tracker.amountSpentThisMonth))
                        .font(.title2.weight(.bold))
                }
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundStyle(Color.bankPrimary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func sectionDetail(_ section: TrackSection) -> some View {
        switch section {
        case .overview:
            if tracker.expenseEntries.isEmpty { firstRunEmptyState } else { dashboard }
        case .ledger:
            ExpenseLedgerView().environment(tracker)
        case .analytics:
            ExpenseAnalyticsDashboardView(tracker: tracker).environment(tracker)
        case .budgets:
            BudgetsView().environment(tracker)
        case .calendar:
            BillCalendarView()
        case .goals:
            SavingsGoalsView()
        case .envelopes:
            EnvelopesView()
        case .netWorth:
            NetWorthView()
        case .imports:
            ImportReviewQueueView()
        }
    }

    private var insightCards: some View {
        VStack(spacing: AppSpacing.md) {
            if let tight = tracker.tightestBudget {
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tight.status == .over ? "Over budget" : "Getting close")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tight.status == .over ? Color.red : Color.orange)
                        Text(tight.category.name)
                            .font(.headline)
                        Text("\(CurrencyFormatter.shared.string(from: tracker.amountSpent(categoryId: tight.category.id))) of \(CurrencyFormatter.shared.string(from: tight.budget.limitAmount))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }

            let uncategorized = tracker.uncategorizedThisMonth
            if !uncategorized.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Uncategorized")
                            .font(.headline)
                        Text("\(uncategorized.count) payment\(uncategorized.count == 1 ? "" : "s") this month have no category, so they are missing from budgets.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        NavigationLink {
                            ExpenseLedgerView().environment(tracker)
                        } label: {
                            Text("Review in the ledger")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }

            let repeats = FinancialIntelligenceService.detectRecurring(transactions: tracker.expenseEntries.filter(\.countsTowardSpending))
            if !repeats.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Looks repeating")
                            .font(.headline)
                        ForEach(repeats.prefix(3)) { item in
                            HStack {
                                Text(item.payee).font(.subheadline)
                                Spacer()
                                Text(CurrencyFormatter.shared.string(from: item.amount))
                                    .font(.subheadline.weight(.semibold))
                                Text("×\(item.occurrences)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                }
            }

            if !tracker.expenseEntries.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latest")
                            .font(.headline)
                        ForEach(tracker.expenseEntries.prefix(4)) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.merchant ?? entry.description)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Text(entry.category ?? "Uncategorized")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(entry.formattedAmount)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .padding(.horizontal)
    }

    private var privacyBanner: some View {
        Button {
            showingPrivacy = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Text("All processing happens on your device")
                    .font(.caption.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(AppSpacing.sm)
            .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .padding(.horizontal)
    }

    private func trackMenuRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle().fill(Color.bankPrimary.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: icon).foregroundStyle(Color.bankPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.bankGroupedBackground, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous))
        .foregroundStyle(.primary)
    }

    private var firstRunEmptyState: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Text("Track")
                    .font(.largeTitle.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, AppSpacing.sm)
                    .accessibilityAddTraits(.isHeader)

                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.bankPrimary)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 8) {
                    Text("Track your spending")
                        .font(.title2.weight(.bold))
                    Text("Log expenses in plain English, snap a receipt, or enter manually — everything stays on your device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }

                ModernButton(title: "Add Your First Expense", systemImage: "plus", variant: .filled) {
                    showingQuickAdd = true
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.sm)

                VStack(spacing: AppSpacing.md) {
                    NavigationLink {
                        ImportReviewQueueView()
                    } label: {
                        trackMenuRow(icon: "tray.full", title: "Review imports", subtitle: "SMS and Account Aggregator")
                    }

                    NavigationLink {
                        SMSImportGuideView()
                    } label: {
                        trackMenuRow(icon: "message", title: "Bank SMS", subtitle: "Captured automatically")
                    }

                    NavigationLink {
                        AggregatorConsentView()
                    } label: {
                        trackMenuRow(icon: "link", title: "Account Aggregator", subtitle: "Sandbox consent and revoke")
                    }

                    NavigationLink {
                        BudgetsView().environment(tracker)
                    } label: {
                        trackMenuRow(icon: "chart.pie.fill", title: "Budgets", subtitle: "\(tracker.budgets.count) active budgets")
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .bankSoftScrollEdges()
    }
}

enum TrackSection: String, CaseIterable, Identifiable, Hashable {
    case overview, ledger, analytics, budgets, calendar, goals, envelopes, netWorth, imports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .ledger: return "Ledger"
        case .analytics: return "Analytics"
        case .budgets: return "Budgets"
        case .calendar: return "Bill calendar"
        case .goals: return "Savings goals"
        case .envelopes: return "Envelopes"
        case .netWorth: return "Net worth"
        case .imports: return "Imports"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .ledger: return "list.bullet.rectangle"
        case .analytics: return "chart.bar.fill"
        case .budgets: return "chart.pie.fill"
        case .calendar: return "calendar"
        case .goals: return "flag.fill"
        case .envelopes: return "envelope.fill"
        case .netWorth: return "chart.line.uptrend.xyaxis"
        case .imports: return "tray.full"
        }
    }
}
