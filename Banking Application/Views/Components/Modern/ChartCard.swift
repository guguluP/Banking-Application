import SwiftUI
import Charts

struct ChartCard<Content: View>: View {
    let title: String
    let systemImage: String?
    let content: Content
    
    init(title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if let systemImage = systemImage {
                        Image(systemName: systemImage)
                            .foregroundColor(Color.bankPrimary)
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                content
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .padding(.horizontal)
    }
}

struct SpendingChartCard: View {
    let data: [SpendingDataPoint]
    @State private var animateChart = false
    
    var body: some View {
        ChartCard(title: "Last 7 Days Spending", systemImage: "chart.bar.fill") {
            if data.isEmpty {
                Text("No spending data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart(data) { point in
                    BarMark(
                        x: .value("Day", point.day),
                        y: .value("Amount", animateChart ? point.amount : 0)
                    )
                    .foregroundStyle(Color.bankPrimary.gradient)
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(format: .currency(code: "INR"))
                }
                .frame(height: 180)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.8)) {
                        animateChart = true
                    }
                }
            }
        }
    }
}

struct CategoryBreakdownChartCard: View {
    let categories: [CategorySpending]
    @State private var animateChart = false
    
    var body: some View {
        ChartCard(title: "Spending by Category", systemImage: "chart.pie.fill") {
            if categories.isEmpty {
                Text("No category data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart(categories) { category in
                    SectorMark(
                        angle: .value("Amount", animateChart ? category.amount : 0),
                        innerRadius: .ratio(0.6),
                        angularInset: 1
                    )
                    .foregroundStyle(category.color.gradient)
                    .opacity(animateChart ? 0.9 : 0.7)
                }
                .animation(.easeOut(duration: 0.8), value: animateChart)
                .frame(height: 180)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.8)) {
                        animateChart = true
                    }
                }
                
                VStack(spacing: 8) {
                    ForEach(categories) { category in
                        HStack {
                            Circle()
                                .fill(category.color)
                                .frame(width: 8, height: 8)
                            Text(category.name)
                                .font(.caption)
                            Spacer()
                            Text(category.formattedAmount)
                                .font(.caption.weight(.medium))
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}