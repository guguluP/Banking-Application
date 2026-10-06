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

    @State private var showingQuickAdd = false
    @State private var showingPrivacy = false

    init(accountViewModel: AccountViewModel, transactionViewModel: TransactionViewModel, modelContext: ModelContext) {
        _tracker = State(initialValue: ExpenseTrackerViewModel(
            modelContext: modelContext,
            accountViewModel: accountViewModel,
            transactionViewModel: transactionViewModel
        ))
    }

    var body: some View {
        NavigationStack {
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
        }
        // Scoped to the NavigationStack itself -- see AccountOverviewView for why.
        .transparentChrome()
        .environment(tracker)
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
        VStack(spacing: AppSpacing.lg) {
            Text("Track")
                .font(.largeTitle.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, AppSpacing.sm)
                .accessibilityAddTraits(.isHeader)

            Spacer()

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

            Spacer()
            Spacer()
        }
    }
}
