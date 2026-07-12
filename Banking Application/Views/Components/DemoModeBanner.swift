import SwiftUI

/// Persistent educational notice: this client uses on-device demo data and is
/// not connected to a licensed bank or real payment rails.
struct DemoModeBanner: View {
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "flask.fill")
                .font(compact ? .caption : .subheadline)
                .foregroundColor(Color.bankAccent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Demo mode")
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                if !compact {
                    Text("Educational sample data only. Not a real bank account or UPI transfer.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(compact ? AppSpacing.sm : AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bankAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous)
                .stroke(Color.bankAccent.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Demo mode. Educational sample data only. Not a real bank account.")
    }
}
