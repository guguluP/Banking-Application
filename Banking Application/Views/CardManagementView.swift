import SwiftUI
import Combine
import SwiftData

struct CardManagementView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @Query private var cards: [Card]
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AppSpacing.lg) {
                    DemoModeBanner()
                        .padding(.horizontal)

                    if cards.isEmpty {
                        ErrorStateView(
                            imageName: "creditcard",
                            title: "No Cards Yet",
                            message: "Demo cards will appear after the first data seed. Pull to refresh, or reinstall the app to reset sample data.",
                            actionTitle: nil,
                            action: nil
                        )
                        .padding()
                    } else {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            VStack(spacing: AppSpacing.md) {
                                CreditCardView(card: card)
                                    .padding(.horizontal)
                                    .scaleEffect(appeared ? 1 : 0.94)
                                    .opacity(appeared ? 1 : 0)
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.82)
                                            .delay(Double(index) * 0.08),
                                        value: appeared
                                    )
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("\(card.cardType.rawValue) card ending \(card.lastFourDigits)")

                                CardControlsView(card: card)
                                    .padding(.horizontal)
                                    .opacity(appeared ? 1 : 0)
                                    .animation(
                                        .easeOut(duration: 0.35).delay(0.12 + Double(index) * 0.08),
                                        value: appeared
                                    )
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .transparentChrome()
            .navigationTitle("Cards")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Label("\(cards.count)", systemImage: "creditcard.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.bankPrimary)
                        .accessibilityLabel("\(cards.count) cards")
                }
            }
            .accessibilityElement(children: .contain)
            .onAppear {
                withAnimation { appeared = true }
            }
        }
    }
}

struct CardControlsView: View {
    @Bindable var card: Card

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Toggle("Contactless Payments", isOn: $card.isContactlessEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .accessibilityLabel("Contactless Payments")
                    .onChange(of: card.isContactlessEnabled) { _, _ in
                        HapticFeedbackService.shared.lightImpact()
                    }

                Toggle("International Usage", isOn: $card.isInternationalUsageEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .accessibilityLabel("International Usage")
                    .onChange(of: card.isInternationalUsageEnabled) { _, _ in
                        HapticFeedbackService.shared.lightImpact()
                    }

                Toggle("Online Transactions", isOn: $card.isOnlineTransactionsEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .accessibilityLabel("Online Transactions")
                    .onChange(of: card.isOnlineTransactionsEnabled) { _, _ in
                        HapticFeedbackService.shared.lightImpact()
                    }

                Divider()
                    .background(Color.secondary.opacity(0.2))

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Spending limits")
                        .font(.subheadline.weight(.medium))

                    LimitProgressRow(
                        title: "Daily",
                        spent: card.dailySpent,
                        limit: card.dailyLimit,
                        progress: card.dailyLimitProgress
                    )

                    LimitProgressRow(
                        title: "Monthly",
                        spent: card.monthlySpent,
                        limit: card.monthlyLimit,
                        progress: card.monthlyLimitProgress
                    )
                }
            }
            .padding()
        }
    }
}

private struct LimitProgressRow: View {
    let title: String
    let spent: Decimal
    let limit: Decimal
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(CurrencyFormatter.shared.string(from: spent)) / \(CurrencyFormatter.shared.string(from: limit))")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
            }
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: progressTint))
                .accessibilityLabel("\(title) spend \(Int(progress * 100)) percent of limit")
        }
    }

    private var progressTint: Color {
        if progress >= 0.9 { return Color.bankDanger }
        if progress >= 0.7 { return Color.bankWarning }
        return Color.bankPrimary
    }
}

struct CardManagementView_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.preview
        let context = container.mainContext
        let tvm = TransactionViewModel(modelContext: context)
        let avm = AccountViewModel(modelContext: context, transactionViewModel: tvm)
        return CardManagementView()
            .environmentObject(avm)
            .modelContainer(container)
            .animatedAppBackground()
    }
}
