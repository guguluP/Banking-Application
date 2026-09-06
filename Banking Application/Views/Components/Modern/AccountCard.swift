import SwiftUI
import Combine

struct AccountCard: View {
    let account: Account
    let action: () -> Void

    @State private var isAnimating = false

    var body: some View {
        Button(action: {
            HapticFeedbackService.shared.lightImpact()
            action()
        }) {
            GlassCard(tint: Color.bankPrimary) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.accountType.rawValue)
                                .font(.caption.weight(.semibold))
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                                .tracking(0.6)

                            Text(account.nickname ?? "Account")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        Image(systemName: accountStatusIcon)
                            .font(.title3)
                            .foregroundStyle(accountStatusColor)
                            .symbolRenderingMode(.hierarchical)
                    }

                    AnimatedDigitText(
                        text: account.formattedBalance,
                        isAnimating: isAnimating,
                        font: AppTheme.Typography.monospacedAmount(),
                        color: .primary,
                        distance: 6,
                        stagger: 0.05
                    )
                    .onAppear { replay() }
                    .onChange(of: account.formattedBalance) { replay() }

                    HStack {
                        Text("Available: \(account.formattedAvailableBalance)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Spacer()

                        Text("•••• \(account.accountNumber.suffix(4))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.bankGroupedBackground, in: Capsule())
                    }
                }
                .padding(AppSpacing.lg)
            }
        }
        .buttonStyle(ScalePressButtonStyle())
        .bankHoverHighlight(AppTheme.CornerRadius.card)
    }

    private func replay() {
        isAnimating = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            isAnimating = true
        }
    }

    private var accountStatusIcon: String {
        account.accountStatus == .active ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var accountStatusColor: Color {
        account.accountStatus == .active ? .bankSuccess : .secondary
    }
}
