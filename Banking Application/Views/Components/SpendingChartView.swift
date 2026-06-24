import SwiftUI
import Charts

struct SpendingChartView: View {
    let data: [SpendingDataPoint]
    @State private var animate = false
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last 7 Days Spending")
                    .font(.headline)
                
                if data.isEmpty {
                    Text("No spending data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    Chart(data) { point in
                        BarMark(
                            x: .value("Day", point.day),
                            y: .value("Amount", animate ? point.amount : 0)
                        )
                        .foregroundStyle(Color.bankPrimary.gradient)
                        .cornerRadius(4)
                    }
                    .chartYAxis {
                        AxisMarks(format: .currency(code: "INR"))
                    }
                    .frame(height: 200)
                    .padding(.vertical)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.8)) {
                            animate = true
                        }
                    }
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
}