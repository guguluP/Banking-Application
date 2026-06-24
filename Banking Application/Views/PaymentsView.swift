import SwiftUI

struct PaymentsView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @State private var selectedPaymentType: PaymentType = .upi
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Payment Type", selection: $selectedPaymentType) {
                    ForEach(PaymentType.allCases, id: \.self) { type in
                        HStack(spacing: 4) {
                            Image(systemName: type.systemImage)
                            Text(type.rawValue)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .accessibilityLabel("Select payment type")
                
                Group {
                    switch selectedPaymentType {
                    case .upi:
                        UPIPaymentEmbedded()
                    case .bills:
                        BillPayEmbedded()
                    }
                }
            }
            .navigationTitle("Payments")
            .searchable(text: $searchText, prompt: "Search payments")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            selectedPaymentType = selectedPaymentType == .upi ? .bills : .upi
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
    }
}

enum PaymentType: String, CaseIterable {
    case upi = "UPI Payment"
    case bills = "Pay Bills"
    
    var systemImage: String {
        switch self {
        case .upi: return "qrcode.viewfinder"
        case .bills: return "doc.text.fill"
        }
    }
}

struct PaymentsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PaymentsView()
                .environmentObject(AccountViewModel(transactionViewModel: TransactionViewModel()))
                .environmentObject(AuthenticationService())
        }
    }
}