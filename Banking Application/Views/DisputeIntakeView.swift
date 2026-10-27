import SwiftUI
import SwiftData

struct DisputeIntakeView: View {
    let transaction: Transaction
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "I don't recognize this"
    @State private var details = ""
    @State private var saveError: String?

    var body: some View {
        Form {
            LabeledContent("Transaction", value: transaction.description)
            LabeledContent("Amount", value: CurrencyFormatter.shared.string(from: transaction.amount))
            TextField("Reason", text: $reason)
            TextField("Details", text: $details, axis: .vertical)
            Button("Submit dispute") {
                let dispute = TransactionDispute(
                    userId: LocalUser.id,
                    transactionId: transaction.id,
                    reason: reason,
                    details: details
                )
                context.insert(dispute)
                do {
                    try context.save()
                    dismiss()
                } catch {
                    context.delete(dispute)
                    saveError = "Couldn't save this dispute. Nothing was filed. \(error.localizedDescription)"
                }
            }
        }
        .navigationTitle("Dispute")
        .alert("Couldn't save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }
}
