import SwiftUI
import SwiftData

// Advanced → Documents (tax certificates, vault, e-Sign).

struct TaxDocumentsView: View {
    @Query private var fds: [FixedDeposit]
    var body: some View {
        let year = Calendar.current.component(.year, from: Date())
        let text = StatementExporter.taxSummary(fds: fds, year: year)
        ScrollView {
            Text(text).font(.body.monospaced()).padding()
        }
        .bankSoftScrollEdges()
        .navigationTitle("Tax docs")
        .toolbar {
            ToolbarItem { ShareLink(item: text) }
        }
    }
}

struct DocumentVaultView: View {
    @Environment(\.modelContext) private var context
    @Query private var docs: [VaultDocument]
    @State private var title = "PAN card"
    @State private var saveError: String?
    var body: some View {
        List {
            Section {
                TextField("Title", text: $title)
                Button("Store metadata") {
                    context.insert(VaultDocument(userId: LocalUser.id, title: title, kind: "KYC"))
                    Ledger.saveOrReport(context, error: $saveError)
                }
            }
            ForEach(docs) { d in
                LabeledContent(d.title, value: d.kind)
            }
        }
        .bankSoftScrollEdges()
        .navigationTitle("Vault")
        .saveFailureAlert($saveError)
        .sensitiveScreenShield()
    }
}

struct ESignView: View {
    @State private var accepted = false
    var body: some View {
        Form {
            Text("Digital consent for new products (FD / loan). This records an on-device acceptance timestamp — production eSign would use a licensed CA.")
            Toggle("I accept the product terms", isOn: $accepted)
            if accepted {
                Text("Consent recorded \(Date.now.formatted())").font(.caption)
            }
        }
        .navigationTitle("e-Sign")
    }
}
