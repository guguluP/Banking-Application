import SwiftUI

struct ExpenseAnalyticsDashboardView: View {
    @EnvironmentObject var tracker: ExpenseTrackerViewModel
    @StateObject private var analytics: ExpenseAnalyticsViewModel

    init(tracker: ExpenseTrackerViewModel) {
        _analytics = StateObject(wrappedValue: ExpenseAnalyticsViewModel(tracker: tracker))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                monthComparisonCard

                if !analytics.topCategories.isEmpty {
                    topCategoriesCard
                } else {
                    emptyState
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Analytics")
    }

    private var monthComparisonCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Spending This Month")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(CurrencyFormatter.shared.string(from: analytics.currentMonthTotal))
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                if let percentChange = analytics.percentChange {
                    HStack(spacing: 4) {
                        Image(systemName: percentChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(abs(percentChange), specifier: "%.1f")% vs last month")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(percentChange >= 0 ? .red : .green)
                } else {
                    Text("No spending last month to compare")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This Month")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.shared.string(from: analytics.currentMonthTotal))
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Last Month")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.shared.string(from: analytics.previousMonthTotal))
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }

    private var topCategoriesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Top Categories")
                    .font(.headline)

                ForEach(analytics.topCategories.prefix(6)) { total in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: total.category.systemImage)
                            .foregroundStyle(total.category.color)
                            .frame(width: 22)
                        Text(total.category.name)
                            .font(.subheadline)
                        Spacer()
                        Text(CurrencyFormatter.shared.string(from: total.amount))
                            .font(.subheadline.weight(.semibold))
                        Text("(\(Int(total.percentOfTotal))%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(total.category.color)
                            .frame(width: geo.size.width * CGFloat(total.percentOfTotal / 100), height: 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.bankGroupedBackground, in: RoundedRectangle(cornerRadius: 3))
                    }
                    .frame(height: 6)
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "chart.pie")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
            Text("No spending yet this month")
                .font(.headline)
            Text("Log an expense to see your analytics here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 60)
    }
}
