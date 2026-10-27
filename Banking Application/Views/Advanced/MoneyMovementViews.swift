import SwiftUI
import SwiftData

// Advanced → Money movement.

struct ScheduledTransfersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ScheduledInstruction.executeOn) private var items: [ScheduledInstruction]
    @Query private var accounts: [Account]
    @State private var payee = ""
    @State private var amount = ""
    @State private var date = Date().addingTimeInterval(86400)
    @State private var standing = false
    @State private var fromAccountId = ""
    @State private var saveError: String?

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
        .saveFailureAlert($saveError)
    }

    private func add() {
        guard let amt = AmountParser.parse(amount), amt > 0, !payee.isEmpty, !fromAccountId.isEmpty else { return }
        let calendar = Calendar.current
        var parts = calendar.dateComponents([.year, .month, .day], from: date)
        parts.hour = 9
        parts.minute = 0
        parts.second = 0
        let executeOn = calendar.date(from: parts) ?? date
        let instruction = ScheduledInstruction(
            userId: LocalUser.id,
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
        guard Ledger.saveOrReport(context, error: $saveError) else { return }
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
    @State private var saveError: String?

    var body: some View {
        Form {
            Section("Collect request") {
                TextField("From / people", text: $name)
                TextField("Amount", text: $amount).keyboardType(.decimalPad)
                TextField("Note", text: $note)
                Toggle("Split bill", isOn: $split)
                if split { TextField("Names, comma-separated", text: $names) }
                Button("Save request") {
                    guard let amt = AmountParser.parse(amount), amt > 0 else { return }
                    let req = MoneyRequest(
                        userId: LocalUser.id,
                        fromName: name,
                        amount: amt,
                        note: note,
                        isCollect: true,
                        isSplit: split,
                        splitNamesCSV: names
                    )
                    context.insert(req)
                    guard Ledger.saveOrReport(context, error: $saveError) else { return }
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
        .saveFailureAlert($saveError)
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
