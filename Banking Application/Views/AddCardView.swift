import SwiftUI
import SwiftData
import SwiftData
import SwiftData

struct AddCardView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
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
            dailyLimit: Decimal(string: dailyLimitText) ?? 0,
            monthlyLimit: Decimal(string: monthlyLimitText) ?? 0
        )
    }

    private var isFormValid: Bool {
        !cardHolderName.trimmingCharacters(in: .whitespaces).isEmpty
            && (Decimal(string: dailyLimitText) ?? 0) > 0
            && (Decimal(string: monthlyLimitText) ?? 0) > 0
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
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Monthly limit")
                                        .font(.subheadline.weight(.semibold))
                                    TextField("50000", text: $monthlyLimitText)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                        .padding(12)
                                        .background(Color(.systemGray6))
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
                .transparentChrome()
                .navigationTitle("Add a Card")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }

                if showingSuccess {
                    AddCardSuccessOverlay(isPresented: $showingSuccess, network: selectedNetwork) {
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

        let daily = Decimal(string: dailyLimitText) ?? 0
        let monthly = Decimal(string: monthlyLimitText) ?? 0

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
                    .fill(isSelected ? Color.bankPrimary : Color(.systemGray6))
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

private struct AddCardSuccessOverlay: View {
    @Binding var isPresented: Bool
    let network: CardType
    let onDone: () -> Void
    @State private var checkmarkScale: CGFloat = 0.4

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: AppSpacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                    .scaleEffect(checkmarkScale)
                    .onAppear {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                            checkmarkScale = 1.0
                        }
                    }

                Text("Card Issued")
                    .font(.headline)

                Text("Your new \(network.rawValue) card is ready to use.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                ModernButton(title: "Done", systemImage: nil, variant: .filled) {
                    dismiss()
                }
                .padding(.top, AppSpacing.sm)
            }
            .padding(AppSpacing.xl)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
            .padding(.horizontal, AppSpacing.xxl)
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
        onDone()
    }
}

struct AddCardView_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.preview
        let context = container.mainContext
        let tvm = TransactionViewModel(modelContext: context)
        let avm = AccountViewModel(modelContext: context, transactionViewModel: tvm)
        return AddCardView()
            .environmentObject(avm)
            .environmentObject(AuthenticationService())
            .modelContainer(container)
            .animatedAppBackground()
    }
}
