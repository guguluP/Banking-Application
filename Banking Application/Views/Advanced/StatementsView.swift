import SwiftUI
import SwiftData

// Advanced → Documents → Statements.

struct StatementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @State private var from = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var to = Date()
    @State private var accountId = "all"
    @State private var pdfPassword = ""
    @State private var rangeCount = 0
    /// Built only when the user taps a prepare button, never while the view renders.
    @State private var csvExport: String?
    @State private var pdfExport: Data?

    private var label: String {
        accounts.first { $0.id == accountId }?.nickname ?? "All accounts"
    }

    var body: some View {
        Form {
            DatePicker("From", selection: $from, displayedComponents: .date)
            DatePicker("To", selection: $to, displayedComponents: .date)
            Picker("Account", selection: $accountId) {
                Text("All accounts").tag("all")
                ForEach(accounts) { account in
                    Text(account.nickname ?? account.accountType.rawValue).tag(account.id)
                }
            }
            if let csvExport {
                ShareLink(item: csvExport, preview: SharePreview("statement.csv")) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
            } else {
                Button {
                    csvExport = StatementExporter.csv(for: rangeTransactions(), accountLabel: label)
                } label: {
                    Label("Prepare CSV", systemImage: "doc.text")
                }
            }
            SecureField("PDF password", text: $pdfPassword)
            if let pdfExport {
                ShareLink(item: pdfExport, preview: SharePreview("statement.pdf")) {
                    Label("Export password PDF", systemImage: "lock.doc")
                }
            } else if !pdfPassword.isEmpty {
                Button {
                    pdfExport = StatementExporter.passwordProtectedPDF(
                        for: rangeTransactions(),
                        accountLabel: label,
                        password: pdfPassword
                    )
                } label: {
                    Label("Prepare password PDF", systemImage: "lock.doc")
                }
            }
            Text("\(rangeCount) transactions in range")
        }
        .navigationTitle("Statements")
        .task(id: rangeKey) {
            csvExport = nil
            pdfExport = nil
            rangeCount = (try? modelContext.fetchCount(rangeDescriptor())) ?? 0
        }
        .onChange(of: pdfPassword) {
            pdfExport = nil
        }
    }

    private var rangeKey: String {
        "\(from.timeIntervalSinceReferenceDate)|\(to.timeIntervalSinceReferenceDate)|\(accountId)"
    }

    /// Only rows inside the chosen dates (and account) are fetched.
    private func rangeDescriptor() -> FetchDescriptor<Transaction> {
        let start = from
        let end = to
        let id = accountId
        let order = [SortDescriptor(\Transaction.transactionDate, order: .reverse)]
        if id == "all" {
            return FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { $0.transactionDate >= start && $0.transactionDate <= end },
                sortBy: order
            )
        }
        return FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.transactionDate >= start && $0.transactionDate <= end && $0.accountId == id },
            sortBy: order
        )
    }

    private func rangeTransactions() -> [Transaction] {
        (try? modelContext.fetch(rangeDescriptor())) ?? []
    }
}
