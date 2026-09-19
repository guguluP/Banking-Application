import SwiftUI
import Combine
import SwiftData

struct CardManagementView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @Query private var cards: [Card]
    @State private var showingAddCard = false

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
                            message: "Apply for a Visa, Mastercard, or RuPay card to get started.",
                            actionTitle: "Add a Card",
                            action: {
                                HapticFeedbackService.shared.lightImpact()
                                showingAddCard = true
                            }
                        )
                        .padding()
                    } else {
                        ForEach(cards) { card in
                            VStack(spacing: AppSpacing.md) {
                                CreditCardView(card: card)
                                    .padding(.horizontal)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("\(card.cardType.rawValue) card ending \(card.lastFourDigits)")

                                CardControlsView(card: card)
                                    .padding(.horizontal)
                            }
                        }

                        ModernButton(title: "Add a Card", systemImage: "plus.circle.fill", variant: .outlined) {
                            showingAddCard = true
                        }
                        .padding(.horizontal)
                        .padding(.top, AppSpacing.sm)
                    }
                }
                .padding(.vertical)
            }
            .bankSoftScrollEdges()
            .navigationTitle("Cards")
            .bankInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: AppSpacing.md) {
                        Label("\(cards.count)", systemImage: "creditcard.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.bankPrimary)
                            .accessibilityLabel("\(cards.count) cards")

                        Button {
                            showingAddCard = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.bankPrimary)
                        }
                        .accessibilityLabel("Add a card")
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .sheet(isPresented: $showingAddCard) {
                AddCardView()
                    .environmentObject(accountViewModel)
            }
        }
        // Scoped to the NavigationStack itself -- see AccountOverviewView for why.
        .transparentChrome()
    }
}

struct CardControlsView: View {
    @Bindable var card: Card
    @EnvironmentObject var authenticationService: AuthenticationService

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Toggle("Freeze card", isOn: Binding(
                    get: { card.cardStatus == .blocked },
                    set: { frozen in
                        authenticationService.stepUpAuthenticate(reason: "Confirm card freeze change") { ok in
                            if ok {
                                card.cardStatus = frozen ? .blocked : .active
                            }
                        }
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .red))

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

