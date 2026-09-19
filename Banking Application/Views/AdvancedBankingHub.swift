import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct AdvancedBankingHub: View {
    var body: some View {
        List {
            Section("Money movement") {
                NavigationLink("Scheduled & standing instructions") { ScheduledTransfersView() }
                NavigationLink("Request / split money") { RequestMoneyView() }
                NavigationLink("International wire") { InternationalWireView() }
                NavigationLink("Round-up savings") { RoundUpSavingsView() }
            }
            Section("Planning") {
                NavigationLink("Savings goals") { SavingsGoalsView() }
                NavigationLink("Envelopes") { EnvelopesView() }
                NavigationLink("Bill calendar") { BillCalendarView() }
                NavigationLink("Net worth") { NetWorthView() }
                NavigationLink("What-if loan") { WhatIfLoanView() }
            }
            Section("Cards & cash") {
                NavigationLink("Virtual cards") { VirtualCardsView() }
                NavigationLink("Cardless ATM") { CardlessATMView() }
                NavigationLink("Replace physical card") { CardReissueView() }
            }
            Section("Documents") {
                NavigationLink("Statements") { StatementsView() }
                NavigationLink("Tax certificates") { TaxDocumentsView() }
                NavigationLink("Document vault") { DocumentVaultView() }
                NavigationLink("e-Sign consents") { ESignView() }
            }
            Section("Trust") {
                NavigationLink("Devices") { DeviceManagementView() }
                NavigationLink("Disputes") { DisputesInboxView() }
                NavigationLink("Family / joint access") { FamilyAccountsView() }
                NavigationLink("Offers") { MerchantOffersView() }
            }
        }
        .bankSoftScrollEdges()
        .navigationTitle("Advanced")
    }
}

struct ScheduledTransfersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ScheduledInstruction.executeOn) private var items: [ScheduledInstruction]
    @Query private var accounts: [Account]
    @State private var payee = ""
    @State private var amount = ""
    @State private var date = Date().addingTimeInterval(86400)
    @State private var standing = false

    var body: some View {
        Form {
            Section("New instruction") {
                TextField("Payee", text: $payee)
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                DatePicker("When", selection: $date, displayedComponents: .date)
                Toggle("Standing (monthly)", isOn: $standing)
                Button("Schedule") { add() }
            }
            Section("Upcoming") {
                ForEach(items) { item in
                    VStack(alignment: .leading) {
                        Text(item.payeeName).font(.headline)
                        Text("\(CurrencyFormatter.shared.string(from: item.amount)) · \(item.frequency.rawValue)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Scheduled")
    }

    private func add() {
        guard let amt = Decimal(string: amount), amt > 0, !payee.isEmpty else { return }
        let row = ScheduledInstruction(
            userId: "user_001",
            fromAccountId: accounts.first?.id ?? "",
            payeeName: payee,
            amount: amt,
            executeOn: date,
            frequency: standing ? .monthly : .once,
            isStandingInstruction: standing
        )
        context.insert(row)
        try? context.save()
        payee = ""; amount = ""
    }
}

struct RequestMoneyView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MoneyRequest.createdAt, order: .reverse) private var requests: [MoneyRequest]
    @State private var name = ""
    @State private var amount = ""
    @State private var note = ""
    @State private var split = false
    @State private var names = ""

    var body: some View {
        Form {
            Section("Collect request") {
                TextField("From / people", text: $name)
                TextField("Amount", text: $amount).keyboardType(.decimalPad)
                TextField("Note", text: $note)
                Toggle("Split bill", isOn: $split)
                if split { TextField("Names, comma-separated", text: $names) }
                Button("Send request") {
                    guard let amt = Decimal(string: amount), amt > 0 else { return }
                    let req = MoneyRequest(
                        userId: "user_001",
                        fromName: name,
                        amount: amt,
                        note: note,
                        isCollect: true,
                        isSplit: split,
                        splitNamesCSV: names
                    )
                    context.insert(req)
                    try? context.save()
                    name = ""; amount = ""; note = ""
                }
            }
            Section("Open requests") {
                ForEach(requests) { r in
                    VStack(alignment: .leading) {
                        Text("\(r.fromName) · \(CurrencyFormatter.shared.string(from: r.amount))")
                        Text(r.isSplit ? "Split: \(r.splitNamesCSV)" : r.note)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Request money")
    }
}

struct InternationalWireView: View {
    @Query private var beneficiaries: [Beneficiary]
    @State private var amount = ""
    @State private var fx = "USD"
    var body: some View {
        Form {
            Section("SWIFT / wire") {
                Picker("Currency", selection: $fx) {
                    Text("USD").tag("USD")
                    Text("EUR").tag("EUR")
                    Text("GBP").tag("GBP")
                }
                TextField("Amount", text: $amount).keyboardType(.decimalPad)
                ForEach(beneficiaries) { b in
                    Text("\(b.nickname) · \(b.bankCode ?? "SWIFT")")
                }
                Text("Indicative INR debit uses a demo FX table. Live rates require a treasury feed.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("International")
    }
}

struct RoundUpSavingsView: View {
    @AppStorage("roundUpEnabled") private var enabled = false
    @AppStorage("roundUpBucket") private var bucket = "Goal"
    var body: some View {
        Form {
            Toggle("Round each debit up to the next ₹10", isOn: $enabled)
            Picker("Sweep into", selection: $bucket) {
                Text("Savings goal").tag("Goal")
                Text("New FD").tag("FD")
            }
            Text("When enabled, the spare change from each completed debit is accumulated toward the selected bucket.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .navigationTitle("Round-up")
    }
}

struct SavingsGoalsView: View {
    @Environment(\.modelContext) private var context
    @Query private var goals: [SavingsGoal]
    @State private var name = "Trip"
    @State private var target = "50000"
    @State private var date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()

    var body: some View {
        Form {
            Section("New goal") {
                TextField("Name", text: $name)
                TextField("Target", text: $target).keyboardType(.decimalPad)
                DatePicker("By", selection: $date, displayedComponents: .date)
                Button("Create") {
                    guard let amt = Decimal(string: target) else { return }
                    context.insert(SavingsGoal(userId: "user_001", name: name, targetAmount: amt, targetDate: date))
                    try? context.save()
                }
            }
            Section {
                ForEach(goals) { g in
                    VStack(alignment: .leading) {
                        Text(g.name)
                        ProgressView(value: g.progress)
                        Text("\(CurrencyFormatter.shared.string(from: g.currentAmount)) of \(CurrencyFormatter.shared.string(from: g.targetAmount))")
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Goals")
    }
}

struct EnvelopesView: View {
    @Environment(\.modelContext) private var context
    @Query private var envelopes: [Envelope]
    @State private var name = "Groceries"
    @State private var amount = "8000"
    var body: some View {
        Form {
            Section("Allocate") {
                TextField("Bucket", text: $name)
                TextField("Amount", text: $amount).keyboardType(.decimalPad)
                Button("Add envelope") {
                    guard let amt = Decimal(string: amount) else { return }
                    context.insert(Envelope(userId: "user_001", name: name, allocated: amt))
                    try? context.save()
                }
            }
            ForEach(envelopes) { e in
                HStack {
                    Text(e.name)
                    Spacer()
                    Text(CurrencyFormatter.shared.string(from: e.remaining))
                }
            }
        }
        .navigationTitle("Envelopes")
    }
}

struct BillCalendarView: View {
    @Query private var loans: [Loan]
    @Query private var fds: [FixedDeposit]
    @Query private var billers: [Biller]
    var body: some View {
        List {
            Section("EMIs") {
                ForEach(loans.filter { $0.status == .active }) { l in
                    LabeledContent(l.nickname, value: l.nextDueDate.formatted(date: .abbreviated, time: .omitted))
                }
            }
            Section("FD maturities") {
                ForEach(fds.filter { $0.status == .active }) { fd in
                    LabeledContent(fd.nickname, value: fd.maturityDate.formatted(date: .abbreviated, time: .omitted))
                }
            }
            Section("Billers") {
                ForEach(billers) { b in
                    Text(b.displayName)
                }
            }
        }
        .bankSoftScrollEdges()
        .navigationTitle("Bill calendar")
    }
}

struct NetWorthView: View {
    @Query private var accounts: [Account]
    @Query private var fds: [FixedDeposit]
    @Query private var loans: [Loan]
    @Environment(\.modelContext) private var context
    @Query(sort: \NetWorthSnapshot.capturedAt) private var snaps: [NetWorthSnapshot]

    private var net: Decimal {
        let assets = accounts.filter { $0.accountType != .credit }.reduce(Decimal(0)) { $0 + $1.balance }
            + fds.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.principal }
        let liab = loans.filter { $0.status == .active }.reduce(Decimal(0)) { $0 + $1.outstandingPrincipal }
        return assets - liab
    }

    var body: some View {
        List {
            Section {
                Text(CurrencyFormatter.shared.string(from: net))
                    .font(.largeTitle.bold())
                Button("Snapshot today") {
                    context.insert(NetWorthSnapshot(userId: "user_001", value: net))
                    try? context.save()
                }
            }
            Section("History") {
                ForEach(snaps) { s in
                    LabeledContent(s.capturedAt.formatted(date: .abbreviated, time: .omitted),
                                   value: CurrencyFormatter.shared.string(from: s.value))
                }
            }
        }
        .bankSoftScrollEdges()
        .navigationTitle("Net worth")
    }
}

struct WhatIfLoanView: View {
    @Query private var loans: [Loan]
    @State private var extra = "20000"
    var body: some View {
        List {
            TextField("Prepay this month", text: $extra).keyboardType(.decimalPad)
            ForEach(loans.filter { $0.status == .active }) { loan in
                let extraAmt = Decimal(string: extra) ?? 0
                let remaining = max(0, loan.outstandingPrincipal - extraAmt)
                VStack(alignment: .leading, spacing: 4) {
                    Text(loan.nickname).font(.headline)
                    Text("Outstanding \(CurrencyFormatter.shared.string(from: loan.outstandingPrincipal))")
                    Text("After prepay \(CurrencyFormatter.shared.string(from: remaining))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .bankSoftScrollEdges()
        .navigationTitle("What-if")
    }
}

struct VirtualCardsView: View {
    @Environment(\.modelContext) private var context
    @Query private var cards: [VirtualCard]
    @State private var merchant = "Amazon"
    var body: some View {
        List {
            Section {
                TextField("Lock to merchant", text: $merchant)
                Button("Issue single-use card") {
                    let four = String((0..<4).map { _ in String(Int.random(in: 0...9)) }.joined())
                    context.insert(VirtualCard(userId: "user_001", lastFour: four, merchantLock: merchant, isSingleUse: true))
                    try? context.save()
                }
            }
            ForEach(cards) { c in
                LabeledContent("•••• \(c.lastFour)", value: c.isActive ? c.merchantLock : "Disabled")
            }
        }
        .bankSoftScrollEdges()
        .navigationTitle("Virtual cards")
        .sensitiveScreenShield()
    }
}

struct CardlessATMView: View {
    @State private var code = ""
    var body: some View {
        VStack(spacing: 16) {
            Text(code.isEmpty ? "Generate a one-time withdrawal code" : code)
                .font(.largeTitle.monospaced())
            Button("Generate") {
                code = String((0..<6).map { _ in String(Int.random(in: 0...9)) }.joined())
            }
            Text("Show this code at a participating ATM within 15 minutes.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Cardless ATM")
        .sensitiveScreenShield()
    }
}

struct CardReissueView: View {
    @Query private var cards: [Card]
    var body: some View {
        List(cards) { card in
            VStack(alignment: .leading) {
                Text("•••• \(card.lastFourDigits)")
                Text("Replacement in transit · expected 5–7 days")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .bankSoftScrollEdges()
        .navigationTitle("Card reissue")
    }
}

struct StatementsView: View {
    @Query private var transactions: [Transaction]
    @State private var from = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var to = Date()
    var body: some View {
        let filtered = transactions.filter { $0.transactionDate >= from && $0.transactionDate <= to }
        let csv = StatementExporter.csv(for: filtered, accountLabel: "All accounts")
        Form {
            DatePicker("From", selection: $from, displayedComponents: .date)
            DatePicker("To", selection: $to, displayedComponents: .date)
            ShareLink(item: csv, preview: SharePreview("statement.csv")) {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
            Text("\(filtered.count) transactions in range")
        }
        .navigationTitle("Statements")
    }
}

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
    var body: some View {
        List {
            Section {
                TextField("Title", text: $title)
                Button("Store metadata") {
                    context.insert(VaultDocument(userId: "user_001", title: title, kind: "KYC"))
                    try? context.save()
                }
            }
            ForEach(docs) { d in
                LabeledContent(d.title, value: d.kind)
            }
        }
        .bankSoftScrollEdges()
        .navigationTitle("Vault")
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

struct DeviceManagementView: View {
    @Environment(\.modelContext) private var context
    @Query private var devices: [DeviceSession]
    var body: some View {
        List {
            Button("Register this device") {
                #if os(macOS)
                let name = "Mac"
                #else
                let name = UIDevice.current.name
                #endif
                context.insert(DeviceSession(userId: "user_001", deviceName: name, platform: "Apple", isCurrent: true))
                try? context.save()
            }
            ForEach(devices) { d in
                HStack {
                    VStack(alignment: .leading) {
                        Text(d.deviceName)
                        Text(d.lastActive.formatted()).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if d.isCurrent { Text("This device").font(.caption) }
                }
            }
            .onDelete { idx in
                idx.map { devices[$0] }.forEach(context.delete)
                try? context.save()
            }
        }
        .bankSoftScrollEdges()
        .navigationTitle("Devices")
    }
}

struct DisputesInboxView: View {
    @Query(sort: \TransactionDispute.createdAt, order: .reverse) private var disputes: [TransactionDispute]
    var body: some View {
        List(disputes) { d in
            VStack(alignment: .leading) {
                Text(d.reason).font(.headline)
                Text(d.statusRaw).font(.caption).foregroundStyle(.secondary)
            }
        }
        .bankSoftScrollEdges()
        .navigationTitle("Disputes")
    }
}

struct FamilyAccountsView: View {
    var body: some View {
        ContentUnavailableView("Family view", systemImage: "person.2", description: Text("Share a read-only balance with a dependent. Full joint posting waits on the server-side identity model."))
            .navigationTitle("Family")
    }
}

struct MerchantOffersView: View {
    var body: some View {
        List {
            LabeledContent("Electricity bill", value: "1% cashback this week")
            LabeledContent("Dining", value: "₹100 off at partner merchants")
        }
        .bankSoftScrollEdges()
        .navigationTitle("Offers")
    }
}

struct SupportHandoffView: View {
    var body: some View {
        Form {
            Text("The on-device assistant couldn't resolve this. A live agent chat would attach here once the backend is live.")
            Button("Request callback") {}
        }
        .navigationTitle("Support")
    }
}
