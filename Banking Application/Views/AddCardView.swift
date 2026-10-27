import SwiftUI
import SwiftData

struct AddCardView: View {
    @Environment(AccountViewModel.self) var accountViewModel
    @EnvironmentObject var authenticationService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedNetwork: CardType = .visa
    @State private var cardHolderName: String = ""
    @State private var dailyLimitText: String = "5000"
    @State private var monthlyLimitText: String = "50000"
    @State private var showingSuccess = false
    @State private var isSubmitting = false

    /// Only these networks are offered for new-card applications. Discover
    /// and plain Debit remain supported card *types* for display/legacy
    /// data, but this app targets Visa / Mastercard / RuPay issuance.
    private let availableNetworks: [CardType] = [.visa, .mastercard, .rupay]

    private var previewCard: Card {
        Card(
            userId: "preview",
            cardNumber: "4242424242424242",
            cardType: selectedNetwork,
            expirationMonth: 12,
            expirationYear: Calendar.current.component(.year, from: Date()) + 4,
            cardHolderName: cardHolderName.isEmpty ? "YOUR NAME" : cardHolderName,
            dailyLimit: AmountParser.parse(dailyLimitText) ?? 0,
            monthlyLimit: AmountParser.parse(monthlyLimitText) ?? 0
        )
    }

    private var isFormValid: Bool {
        !cardHolderName.trimmingCharacters(in: .whitespaces).isEmpty
            && (AmountParser.parse(dailyLimitText) ?? 0) > 0
            && (AmountParser.parse(monthlyLimitText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        CreditCardView(card: previewCard, reactsToTilt: false)
                            .padding(.horizontal)
                            .padding(.top, AppSpacing.sm)
                            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedNetwork)

                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Choose network")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal)

                            HStack(spacing: AppSpacing.sm) {
                                ForEach(availableNetworks, id: \.self) { network in
                                    NetworkChoiceChip(
                                        network: network,
                                        isSelected: selectedNetwork == network
                                    ) {
                                        HapticFeedbackService.shared.lightImpact()
                                        selectedNetwork = network
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                                Text("Card details")
                                    .font(.subheadline.weight(.semibold))

                                FormFieldView(
                                    label: "Cardholder name",
                                    placeholder: "As it should appear on the card",
                                    text: $cardHolderName
                                )

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Daily limit")
                                        .font(.subheadline.weight(.semibold))
                                    TextField("5000", text: $dailyLimitText)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                        .padding(12)
                                        .background(Color.bankGroupedBackground)
                                        .cornerRadius(8)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Monthly limit")
                                        .font(.subheadline.weight(.semibold))
                                    TextField("50000", text: $monthlyLimitText)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                        .padding(12)
                                        .background(Color.bankGroupedBackground)
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                        }
                        .padding(.horizontal)

                        DemoModeBanner()
                            .padding(.horizontal)

                        ModernButton(
                            title: isSubmitting ? "Issuing card…" : "Apply for card",
                            systemImage: isSubmitting ? nil : "plus.circle.fill",
                            variant: .filled
                        ) {
                            submit()
                        }
                        .disabled(!isFormValid || isSubmitting)
                        .opacity(isFormValid ? 1 : 0.5)
                        .padding(.horizontal)
                        .padding(.bottom, AppSpacing.xl)
                    }
                }
                .bankSoftScrollEdges()
                .transparentChrome()
                .navigationTitle("Add a Card")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }

                if showingSuccess {
                    SuccessOverlay(
                        style: .check(
                            title: "Card Issued",
                            message: "Your new \(selectedNetwork.rawValue) card is ready to use.",
                            dismissAfter: .milliseconds(1800)
                        ),
                        isPresented: $showingSuccess
                    ) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func submit() {
        guard let userId = authenticationService.user?.id, isFormValid else { return }
        isSubmitting = true
        HapticFeedbackService.shared.lightImpact()

        let daily = AmountParser.parse(dailyLimitText) ?? 0
        let monthly = AmountParser.parse(monthlyLimitText) ?? 0

        let created = accountViewModel.addCard(
            userId: userId,
            cardType: selectedNetwork,
            cardHolderName: cardHolderName.trimmingCharacters(in: .whitespaces),
            dailyLimit: daily,
            monthlyLimit: monthly
        )

        isSubmitting = false
        if created != nil {
            withAnimation { showingSuccess = true }
        }
    }
}

private struct NetworkChoiceChip: View {
    let network: CardType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            VStack(spacing: 6) {
                Text(shortLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                    .fill(isSelected ? Color.bankPrimary : Color.bankGroupedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium, style: .continuous)
                    .stroke(isSelected ? Color.bankPrimary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(network.rawValue)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var shortLabel: String {
        switch network {
        case .rupay: return "RuPay"
        case .mastercard: return "Mastercard"
        default: return network.rawValue
        }
    }
}

struct AddCardView_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.preview
        let context = container.mainContext
        let tvm = TransactionViewModel(modelContext: context)
        let avm = AccountViewModel(modelContext: context, transactionViewModel: tvm)
        return AddCardView()
            .environment(avm)
            .environmentObject(AuthenticationService())
            .modelContainer(container)
            .animatedAppBackground()
    }
}
