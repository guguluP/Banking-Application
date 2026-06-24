import SwiftUI

struct CardManagementView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @State private var cards: [Card] = [
        Card(id: "card_001", userId: "user_001", cardNumber: "4111111111111111", cardType: .visa, cardStatus: .active, expirationMonth: 12, expirationYear: 2025, cardHolderName: "JOHN DOE", cvv: "123", issueDate: Date(timeIntervalSinceNow: -31536000), dailyLimit: Decimal(1000), monthlyLimit: Decimal(5000), isContactlessEnabled: true, isInternationalUsageEnabled: true, isOnlineTransactionsEnabled: true),
        Card(id: "card_002", userId: "user_001", cardNumber: "5555555555554444", cardType: .mastercard, cardStatus: .active, expirationMonth: 8, expirationYear: 2024, cardHolderName: "JOHN DOE", cvv: "456", issueDate: Date(timeIntervalSinceNow: -180*86400), dailyLimit: Decimal(500), monthlyLimit: Decimal(3000), isContactlessEnabled: true, isInternationalUsageEnabled: false, isOnlineTransactionsEnabled: true)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach($cards) { $card in
                        GlassCard {
                            CreditCardView(card: $card)
                        }
                        .accessibilityElement(children: .combine)
                        
                        CardControlsView(card: $card)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("My Cards")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .accessibilityLabel("Edit cards")
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

struct CardControlsView: View {
    @Binding var card: Card
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Toggle("Contactless Payments", isOn: $card.isContactlessEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .accessibilityLabel("Contactless Payments")
                
                Toggle("International Usage", isOn: $card.isInternationalUsageEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .accessibilityLabel("International Usage")
                
                Toggle("Online Transactions", isOn: $card.isOnlineTransactionsEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .accessibilityLabel("Online Transactions")
                
                Divider()
                    .background(Color.secondary.opacity(0.2))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Limits")
                        .font(.subheadline.weight(.medium))
                    
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(CurrencyFormatter.shared.string(from: card.dailyLimit))
                                .font(.caption.weight(.medium))
                        }
                        
                        Spacer()
                        
                        ProgressView(value: 0.3)
                            .progressViewStyle(LinearProgressViewStyle(tint: Color.bankPrimary))
                            .frame(width: 80)
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monthly")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(CurrencyFormatter.shared.string(from: card.monthlyLimit))
                                .font(.caption.weight(.medium))
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct CardManagementView_Previews: PreviewProvider {
    static var previews: some View {
        CardManagementView()
            .environmentObject(AccountViewModel(transactionViewModel: TransactionViewModel()))
    }
}