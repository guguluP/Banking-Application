import SwiftUI

struct ModernTransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Circle()
                .fill(transactionIconColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: transactionIcon)
                        .foregroundColor(transactionIconColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let counterparty = transaction.counterparty {
                    Text(counterparty)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(transaction.transactionDate, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(transaction.formattedAmount)
                .font(.subheadline.weight(.medium))
                .foregroundColor(transaction.isCredit ? .green : .red)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private var transactionIcon: String {
        switch transaction.type {
        case .deposit: return "arrow.down.doc.fill"
        case .withdrawal: return "arrow.up.doc.fill"
        case .transfer: return "arrow.left.arrow.right"
        case .payment: return "indianrupee.circle.fill"
        case .fee: return "exclamationmark.triangle.fill"
        case .interest: return "percent"
        }
    }
    
    private var transactionIconColor: Color {
        switch transaction.type {
        case .deposit, .interest: return .green
        case .withdrawal, .payment, .fee: return .red
        case .transfer: return .blue
        }
    }
}