import SwiftUI
import SwiftData

// Advanced → Planning.

struct SavingsGoalsView: View {
    @Environment(\.modelContext) private var context
    @Query private var goals: [SavingsGoal]
    @Query private var deposits: [FixedDeposit]
    @State private var name = "Trip"
    @State private var target = "50000"
    @State private var date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var saveError: String?

    var body: some View {
        Form {
            Section("New goal") {
                TextField("Name", text: $name)
                TextField("Target", text: $target).keyboardType(.decimalPad)
                DatePicker("By", selection: $date, displayedComponents: .date)
                Button("Create") {
                    guard let amt = AmountParser.parse(target) else { return }
                    context.insert(SavingsGoal(userId: LocalUser.id, name: name, targetAmount: amt, targetDate: date))
                    Ledger.saveOrReport(context, error: $saveError)
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
        .saveFailureAlert($saveError)
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
    @State private var saveError: String?
    var body: some View {
        Form {
            Section("Allocate") {
                TextField("Bucket", text: $name)
                TextField("Amount", text: $amount).keyboardType(.decimalPad)
                Button("Add envelope") {
                    guard let amt = AmountParser.parse(amount) else { return }
                    context.insert(Envelope(userId: LocalUser.id, name: name, allocated: amt))
                    Ledger.saveOrReport(context, error: $saveError)
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
        .saveFailureAlert($saveError)
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
    @State private var saveError: String?

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
                    context.insert(NetWorthSnapshot(userId: LocalUser.id, value: net))
                    Ledger.saveOrReport(context, error: $saveError)
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
        .saveFailureAlert($saveError)
    }
}

struct WhatIfLoanView: View {
    @Query private var loans: [Loan]
    @State private var extra = "20000"
    var body: some View {
        List {
            TextField("Prepay this month", text: $extra).keyboardType(.decimalPad)
            ForEach(loans.filter { $0.status == .active }) { loan in
                let extraAmt = AmountParser.parse(extra) ?? 0
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
