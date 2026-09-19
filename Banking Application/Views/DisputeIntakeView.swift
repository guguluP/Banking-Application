import SwiftUI
import SwiftData

struct DisputeIntakeView: View {
    let transaction: Transaction
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "I don't recognize this"
    @State private var details = ""

    var body: some View {
        Form {
            LabeledContent("Transaction", value: transaction.description)
            LabeledContent("Amount", value: CurrencyFormatter.shared.string(from: transaction.amount))
            TextField("Reason", text: $reason)
            TextField("Details", text: $details, axis: .vertical)
            Button("Submit dispute") {
                context.insert(TransactionDispute(
                    userId: "user_001",
                    transactionId: transaction.id,
                    reason: reason,
                    details: details
                ))
                try? context.save()
                dismiss()
            }
        }
        .navigationTitle("Dispute")
    }
}
