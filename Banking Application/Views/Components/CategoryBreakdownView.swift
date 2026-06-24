import SwiftUI
import Charts

struct CategoryBreakdownView: View {
    let categories: [CategorySpending]
    @State private var animate = false
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Spending by Category")
                    .font(.headline)
                
                if categories.isEmpty {
                    Text("No category data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    Chart(categories) { category in
                        SectorMark(
                            angle: .value("Amount", animate ? category.amount : 0),
                            innerRadius: .ratio(0.6),
                            angularInset: 1
                        )
                        .foregroundStyle(category.color.gradient)
                        .opacity(animate ? 0.9 : 0.5)
                    }
                    .animation(.easeOut(duration: 0.8), value: animate)
                    .frame(height: 200)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.8)) {
                            animate = true
                        }
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(categories) { category in
                            HStack(spacing: 8) {
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
            .padding()
        }
        .padding(.horizontal)
    }
}