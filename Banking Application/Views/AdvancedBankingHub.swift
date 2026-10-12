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
                NavigationLink("International wire quote") { InternationalWireView() }
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
                NavigationLink("Security activity") { SecurityActivityView() }
                NavigationLink("Limits") { LimitSettingsView() }
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
    @State private var fromAccountId = ""

    private var accountChoices: [Account] {
        accounts.sorted {
            let left = $0.nickname ?? $0.accountType.rawValue
            let right = $1.nickname ?? $1.accountType.rawValue
            return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }
    }

    var body: some View {
        Form {
            Section("New instruction") {
                Picker("From account", selection: $fromAccountId) {
                    Text("Select an account").tag("")
                    ForEach(accountChoices) { account in
                        Text(account.nickname ?? account.accountType.rawValue).tag(account.id)
                    }
                }
                TextField("Payee", text: $payee)
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                DatePicker("When", selection: $date, displayedComponents: .date)
                Toggle("Standing (monthly)", isOn: $standing)
                Button("Schedule") { add() }
                    .disabled(fromAccountId.isEmpty)
            }
            Section("Upcoming") {
                ForEach(items) { item in
                    VStack(alignment: .leading) {
                        Text(item.payeeName).font(.headline)
                        Text("\(CurrencyFormatter.shared.string(from: item.amount)) · \(item.frequency.rawValue)")
                            .font(.caption).foregroundStyle(.secondary)
                        if !item.lastError.isEmpty {
                            Text(item.lastError)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("Scheduled")
    }

    private func add() {
        guard let amt = Decimal(string: amount), amt > 0, !payee.isEmpty, !fromAccountId.isEmpty else { return }
        let calendar = Calendar.current
        var parts = calendar.dateComponents([.year, .month, .day], from: date)
        parts.hour = 9
        parts.minute = 0
        parts.second = 0
        let executeOn = calendar.date(from: parts) ?? date
        let instruction = ScheduledInstruction(
            userId: "user_001",
            fromAccountId: fromAccountId,
            payeeName: payee,
            amount: amt,
            executeOn: executeOn,
            frequency: standing ? .monthly : .once,
            isStandingInstruction: standing
        )
        if standing {
            instruction.scheduledDay = calendar.component(.day, from: executeOn)
        }
        context.insert(instruction)
        try? context.save()
        payee = ""
        amount = ""
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
                Button("Save request") {
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
                Text("Saves the request on this device. Nothing is sent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            Section("Quote only — this does not send a wire") {
                Picker("Currency", selection: $fx) {
                    Text("USD").tag("USD")
                    Text("EUR").tag("EUR")
                    Text("GBP").tag("GBP")
                }
                TextField("Amount", text: $amount).keyboardType(.decimalPad)
                ForEach(beneficiaries) { b in
                    Text("\(b.nickname) · \(b.bankCode ?? "SWIFT")")
                }
                Text("This is a quote. It does not send a wire. Indicative rates are a demo table, not a live treasury feed.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Wire quote")
    }
}

struct RoundUpSavingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Toggle("Round each debit up to the next ₹10", isOn: $settings.isRoundUpEnabled)
            Text("Spare change moves to another active savings account. It is skipped when there is nowhere to put it. UPI and bills are not rounded.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .navigationTitle("Round-up")
    }
}

struct SavingsGoalsView: View {
    @Environment(\.modelContext) private var context
    @Query private var goals: [SavingsGoal]
    @Query private var deposits: [FixedDeposit]
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
                    let saved = linkedSavings(for: g)
                    VStack(alignment: .leading) {
                        Text(g.name)
                        ProgressView(value: progress(saved: saved, target: g.targetAmount))
                        Text("\(CurrencyFormatter.shared.string(from: saved)) of \(CurrencyFormatter.shared.string(from: g.targetAmount))")
                            .font(.caption)
                        Text(g.linkedFDId == nil ? "Not linked to a deposit yet. The bar stays at the saved amount." : "Includes the linked fixed deposit.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Goals")
    }

    private func linkedSavings(for goal: SavingsGoal) -> Decimal {
        if let id = goal.linkedFDId, let deposit = deposits.first(where: { $0.id == id && $0.status == .active }) {
            return deposit.principal + goal.currentAmount
        }
        return goal.currentAmount
    }

    private func progress(saved: Decimal, target: Decimal) -> Double {
        guard target > 0 else { return 0 }
        return min(1, NSDecimalNumber(decimal: saved / target).doubleValue)
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
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(e.name)
                        Spacer()
                        Text(CurrencyFormatter.shared.string(from: e.remaining))
                    }
                    ProgressView(value: e.allocated > 0 ? min(1, NSDecimalNumber(decimal: e.spent / e.allocated).doubleValue) : 0)
                    Text("\(CurrencyFormatter.shared.string(from: e.spent)) spent of \(CurrencyFormatter.shared.string(from: e.allocated)). A matching expense category reduces this.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Envelopes")
    }
}

struct BillCalendarView: View {
    @Query private var loans: [Loan]
    @Query private var fds: [FixedDeposit]
    @Query private var scheduled: [ScheduledInstruction]

    private struct Item: Identifiable {
        var id: String
        var date: Date
        var title: String
        var detail: String
    }

    private var items: [Item] {
        var rows: [Item] = []
        for loan in loans where loan.status == .active {
            rows.append(Item(id: "loan-\(loan.id)", date: loan.nextDueDate, title: loan.nickname, detail: "EMI \(loan.formattedEMI)"))
        }
        for deposit in fds where deposit.status == .active {
            rows.append(Item(id: "fd-\(deposit.id)", date: deposit.maturityDate, title: deposit.nickname, detail: "Matures \(CurrencyFormatter.shared.string(from: deposit.maturityValue))"))
        }
        for item in scheduled where item.status == .scheduled {
            let detail = item.lastError.isEmpty ? CurrencyFormatter.shared.string(from: item.amount) : item.lastError
            rows.append(Item(id: "sched-\(item.id)", date: item.executeOn, title: item.payeeName, detail: detail))
        }
        return rows.sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            if items.isEmpty {
                Text("No EMIs, deposit maturities, or scheduled payments yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                    Text("\(item.date.formatted(date: .abbreviated, time: .omitted)) · \(item.detail)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
    @Query private var accounts: [Account]
    @State private var from = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var to = Date()
    @State private var accountId = "all"
    @State private var pdfPassword = ""
    var body: some View {
        let filtered = transactions.filter { tx in
            tx.transactionDate >= from && tx.transactionDate <= to
                && (accountId == "all" || tx.accountId == accountId)
        }
        let label = accounts.first { $0.id == accountId }?.nickname ?? "All accounts"
        let csv = StatementExporter.csv(for: filtered, accountLabel: label)
        Form {
            DatePicker("From", selection: $from, displayedComponents: .date)
            DatePicker("To", selection: $to, displayedComponents: .date)
            Picker("Account", selection: $accountId) {
                Text("All accounts").tag("all")
                ForEach(accounts) { account in
                    Text(account.nickname ?? account.accountType.rawValue).tag(account.id)
                }
            }
            ShareLink(item: csv, preview: SharePreview("statement.csv")) {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
            SecureField("PDF password", text: $pdfPassword)
            if let data = StatementExporter.passwordProtectedPDF(for: filtered, accountLabel: label, password: pdfPassword), !pdfPassword.isEmpty {
                ShareLink(item: data, preview: SharePreview("statement.pdf")) {
                    Label("Export password PDF", systemImage: "lock.doc")
                }
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
    @State private var showCallbackNote = false

    var body: some View {
        Form {
            Text("The on-device assistant couldn't resolve this. A live agent chat would attach here once the backend is live.")
            Button("Request callback") { showCallbackNote = true }
        }
        .navigationTitle("Support")
        .alert("Callback not sent", isPresented: $showCallbackNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Callback requests are not sent in this demo. Nothing was shared with a bank.")
        }
    }
}
