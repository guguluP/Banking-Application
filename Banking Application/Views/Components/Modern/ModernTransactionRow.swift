import SwiftUI

struct ModernTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                transactionIconColor.opacity(0.22),
                                transactionIconColor.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)

                Image(systemName: transactionIcon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(transactionIconColor)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.description)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let counterparty = transaction.counterparty {
                    Text(counterparty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(transaction.transactionDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.formattedAmount)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(transaction.isCredit ? Color.bankSuccess : Color.primary)

                if transaction.isCredit {
                    Text("Credit")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.bankSuccess.opacity(0.85))
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .bankHoverHighlight(AppTheme.CornerRadius.medium)
        .accessibilityElement(children: .combine)
    }

    private var transactionIcon: String {
        switch transaction.type {
        case .deposit: return "arrow.down.circle.fill"
        case .withdrawal: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        case .payment: return "indianrupee.circle.fill"
        case .fee: return "exclamationmark.triangle.fill"
        case .interest: return "percent"
        }
    }

    private var transactionIconColor: Color {
        switch transaction.type {
        case .deposit, .interest: return .bankSuccess
        case .withdrawal, .fee: return .bankDanger
        case .payment: return .bankAccent
        case .transfer: return .bankPrimary
        }
    }
}
