import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ImportReviewQueueView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ImportedEvent.occurredAt, order: .reverse) private var rows: [ImportedEvent]

    var body: some View {
        List {
            Section("Needs a look") {
                let pending = rows.filter { $0.status == .pendingReview }
                if pending.isEmpty {
                    Text("Nothing waiting.")
                }
                ForEach(pending) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row.merchant.isEmpty ? row.bank : row.merchant)
                        Text("\(row.amount.description) · •••• \(row.accountLast4) · \(row.categoryName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Save") { _ = BankImportPipeline.approve(row, in: context) }
                            Button("Skip") { BankImportPipeline.reject(row, in: context) }
                        }
                    }
                }
            }
            Section("Recent imports") {
                ForEach(rows.filter { $0.status != .pendingReview }) { row in
                    LabeledContent(row.merchant.isEmpty ? row.bank : row.merchant, value: row.statusRaw)
                }
            }
        }
        .navigationTitle("Review imports")
    }
}

struct SMSImportGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bank SMS")
                    .font(.title2.bold())
                Text("BankSecure records bank texts itself. You do not set up a Shortcut. When a bank SMS arrives, the message filter keeps the amount, payee, last four digits, and reference, then drops the text. OTP messages are ignored.")
                Text("iOS still requires one switch, which only you can turn on: Settings, Messages, Unknown & Spam, then enable BankSecure.")
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("SMS capture")
    }
}

struct AggregatorConsentView: View {
    @Environment(\.modelContext) private var context
    @Query private var consents: [AAConsent]
    @State private var mobile = ""
    @State private var status = "Sandbox only. A production Account Aggregator link needs a regulated partner."

    var body: some View {
        Form {
            Section("New consent") {
                TextField("Mobile number", text: $mobile)
                    .keyboardType(.phonePad)
                Button("Create sandbox consent") { Task { await create() } }
                    .disabled(mobile.count < 10)
                Text(status).font(.footnote)
            }
            Section("Active consents") {
                ForEach(consents) { consent in
                    VStack(alignment: .leading) {
                        Text(consent.mobile)
                        Text("\(consent.provider) · \(consent.status)").font(.caption)
                    }
                }
                Button("Revoke and delete imported AA data", role: .destructive) {
                    for consent in consents { context.delete(consent) }
                    BankImportPipeline.deleteAggregatorImports(in: context)
                    try? context.save()
                }
            }
        }
        .navigationTitle("Account Aggregator")
    }

    private func create() async {
        do {
            let id = try await AggregatorClient.createConsent(mobile: mobile)
            let events = try await AggregatorClient.fetchEvents(consentId: id)
            for event in events {
                _ = BankImportPipeline.ingest(event, in: context)
            }
            context.insert(AAConsent(mobile: mobile, provider: "sandbox"))
            try? context.save()
            status = "Consent \(id) fetched. The sample backend deletes the payload after the first read, so run fetch once in your own server if you need a single shot."
        } catch {
            status = "The sandbox backend is not running at \(AggregatorClient.baseURL.absoluteString)."
        }
    }
}

struct SecurityActivityView: View {
    @Query(sort: \SecurityEvent.createdAt, order: .reverse) private var events: [SecurityEvent]
    var body: some View {
        List(events) { event in
            VStack(alignment: .leading) {
                Text(event.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                Text(event.detail).font(.caption).foregroundStyle(.secondary)
                Text(event.createdAt.formatted()).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .navigationTitle("Security activity")
    }
}

struct LimitSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    var body: some View {
        Form {
            Section("Transfers") {
                limitField("Daily", value: $settings.dailyTransferLimit)
                limitField("Monthly", value: $settings.monthlyTransferLimit)
            }
            Section("UPI") {
                limitField("Daily", value: $settings.dailyUPILimit)
                limitField("Monthly", value: $settings.monthlyUPILimit)
            }
            Section("Bill pay") {
                limitField("Daily", value: $settings.dailyBillPayLimit)
                limitField("Monthly", value: $settings.monthlyBillPayLimit)
            }
            Section("Alerts and new payees") {
                limitField("Large payment alert", value: $settings.largeTransactionAmount)
                limitField("Cooling-off large amount", value: $settings.coolingLargeAmount)
            }
            Button("Save limits") { settings.persistLimits() }
        }
        .navigationTitle("Limits")
    }

    private func limitField(_ title: String, value: Binding<Decimal>) -> some View {
        TextField(title, text: Binding(
            get: { NSDecimalNumber(decimal: value.wrappedValue).stringValue },
            set: { value.wrappedValue = Decimal(string: $0) ?? value.wrappedValue }
        ))
        .keyboardType(.decimalPad)
    }
}
