import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

@main
struct PaymentLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PaymentActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: context.state.isComplete ? "checkmark.circle.fill" : "indianrupee.circle.fill")
                    .font(.title2)
                    .foregroundStyle(context.state.isComplete ? .green : .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.isComplete ? "\(context.attributes.paymentKind) sent" : "\(context.attributes.paymentKind) in progress")
                        .font(.headline)
                    Text("\(context.state.amountText) · \(context.attributes.counterparty)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(context.state.status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "building.columns.fill")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.amountText)
                        .font(.headline)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.paymentKind) · \(context.attributes.counterparty)")
                        .font(.caption)
                }
            } compactLeading: {
                Image(systemName: context.state.isComplete ? "checkmark" : "arrow.left.arrow.right")
            } compactTrailing: {
                Text(context.state.amountText)
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "indianrupee.circle.fill")
            }
        }
    }
}
