import SwiftUI
import Combine
import SwiftData

struct PaymentsView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @State private var selectedPaymentType: PaymentType = .upi
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PillSegmentedControl(
                    selection: $selectedPaymentType,
                    items: PaymentType.allCases,
                    icon: { $0.systemImage }
                )
                .padding()
                .adaptiveContentWidth()
                .accessibilityLabel("Select payment type")

                Group {
                    switch selectedPaymentType {
                    case .upi:
                        UPIPaymentContent()
                    case .bills:
                        BillPayContent(enableSearch: false, externalSearchText: searchText)
                    case .send:
                        TransferView(isEmbedded: true)
                    case .request:
                        RequestMoneyView()
                    }
                }
                .adaptiveContentWidth()
            }
            .navigationTitle("Payments")
            .searchableIf(selectedPaymentType == .bills, text: $searchText, prompt: "Search billers")
            .autocorrectionDisabled(true)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        withAnimation(AppTheme.Animation.standard) {
                            let all = PaymentType.allCases
                            if let idx = all.firstIndex(of: selectedPaymentType) {
                                selectedPaymentType = all[(idx + 1) % all.count]
                            }
                        }
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Switch payment type")
                }
            }
            .accessibilityElement(children: .contain)
        }
        // Scoped to the NavigationStack itself -- see AccountOverviewView for why.
        .transparentChrome()
    }
}

enum PaymentType: String, CaseIterable {
    case upi = "UPI Payment"
    case bills = "Pay Bills"
    case send = "Send Money"
    case request = "Request"

    var systemImage: String {
        switch self {
        case .upi: return "qrcode.viewfinder"
        case .bills: return "doc.text.fill"
        case .send: return "paperplane.fill"
        case .request: return "arrow.down.left"
        }
    }
}

struct PaymentsView_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.preview
        let context = container.mainContext
        let tvm = TransactionViewModel(modelContext: context)
        let avm = AccountViewModel(modelContext: context, transactionViewModel: tvm)
        return NavigationStack {
            PaymentsView()
                .environmentObject(avm)
                .environmentObject(tvm)
                .environmentObject(AuthenticationService())
        }
        .modelContainer(container)
    }
}
