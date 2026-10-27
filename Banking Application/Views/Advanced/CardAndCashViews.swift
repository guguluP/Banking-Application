import SwiftUI
import SwiftData

// Advanced → Cards & cash.

struct VirtualCardsView: View {
    @Environment(\.modelContext) private var context
    @Query private var cards: [VirtualCard]
    @State private var merchant = "Amazon"
    @State private var saveError: String?
    var body: some View {
        List {
            Section {
                TextField("Lock to merchant", text: $merchant)
                Button("Issue single-use card") {
                    let four = String((0..<4).map { _ in String(Int.random(in: 0...9)) }.joined())
                    context.insert(VirtualCard(userId: LocalUser.id, lastFour: four, merchantLock: merchant, isSingleUse: true))
                    Ledger.saveOrReport(context, error: $saveError)
                }
            }
            ForEach(cards) { c in
                LabeledContent("•••• \(c.lastFour)", value: c.isActive ? c.merchantLock : "Disabled")
            }
        }
        .bankSoftScrollEdges()
        .navigationTitle("Virtual cards")
        .saveFailureAlert($saveError)
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
