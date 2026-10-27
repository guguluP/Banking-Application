import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

// Advanced → Trust, plus the support hand-off screen.

struct DeviceManagementView: View {
    @Environment(\.modelContext) private var context
    @Query private var devices: [DeviceSession]
    @State private var saveError: String?
    var body: some View {
        List {
            Button("Register this device") {
                #if os(macOS)
                let name = "Mac"
                #else
                let name = UIDevice.current.name
                #endif
                context.insert(DeviceSession(userId: LocalUser.id, deviceName: name, platform: "Apple", isCurrent: true))
                Ledger.saveOrReport(context, error: $saveError)
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
                Ledger.saveOrReport(context, error: $saveError)
            }
        }
        .bankSoftScrollEdges()
        .navigationTitle("Devices")
        .saveFailureAlert($saveError)
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
