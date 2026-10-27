import SwiftUI
import SwiftData

/// Shown as soon as a real session starts, and again from Home and Track.
/// The user names each account by bank and last four digits. Those digits are
/// what a bank SMS carries, so an expense can be filed on the right account
/// even when the accounts belong to different banks.
struct SpendAccountSetupView: View {
    var isAddingMore: Bool = false
    var onFinished: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.openedDate) private var accounts: [Account]

    @State private var drafts: [SpendAccountDraft] = [SpendAccountDraft()]
    @State private var message: String?

    private var declared: [Account] {
        accounts.filter(\.isDeclaredSpendAccount)
    }

    private var prepared: [(bank: String, last4: String)] {
        drafts.map {
            (Account.canonicalBank($0.bankName), String($0.last4.filter(\.isNumber).prefix(4)))
        }
    }

    private var canSave: Bool {
        let rows = prepared
        guard rows.allSatisfy({ !$0.bank.isEmpty && $0.last4.count == 4 }) else { return false }
        let keys = rows.map { "\($0.bank.lowercased())|\($0.last4)" }
        guard Set(keys).count == keys.count else { return false }
        let existing = Set(declared.map { "\(Account.canonicalBank($0.bankName).lowercased())|\(String($0.accountNumber.suffix(4)))" })
        return keys.allSatisfy { !existing.contains($0) }
    }

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Which accounts do you spend from?")
                            .font(.title2.weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        Text("Name the bank and the last 4 digits of each account. A bank text carries those digits, so each expense can show which account it left — including two accounts at the same bank, or accounts at different banks. The full number stays at your bank. This does not open an account or show that bank's balance.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if isAddingMore && !declared.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Already added")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(declared) { account in
                                Text(account.expenseAccountLabel)
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }

                    ForEach(drafts) { draft in
                        SpendAccountDraftCard(
                            draft: binding(for: draft.id),
                            onRemove: drafts.count > 1 ? { drafts.removeAll { $0.id == draft.id } } : nil
                        )
                    }

                    Button {
                        drafts.append(SpendAccountDraft())
                    } label: {
                        Label("Add another account", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.bankPrimary)

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Color.bankDanger)
                    } else if !canSave {
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ModernButton(
                        title: isAddingMore ? "Save account" : "See my expenses",
                        systemImage: "arrow.right.circle.fill",
                        isEnabled: canSave
                    ) {
                        save()
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .bankSoftScrollEdges()
        }
        .navigationTitle(isAddingMore ? "Add account" : "Your accounts")
        .bankInlineNavigationTitle()
        .toolbar {
            if isAddingMore {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var hint: String {
        let rows = prepared
        let keys = rows.map { "\($0.bank.lowercased())|\($0.last4)" }
        if Set(keys).count != keys.count || declared.contains(where: { existing in
            rows.contains { Account.sameBank($0.bank, existing.bankName) && $0.last4 == String(existing.accountNumber.suffix(4)) }
        }) {
            return "That bank and those digits are already listed."
        }
        return "Enter the bank and the last 4 digits. You can add more than one account."
    }

    private func binding(for id: UUID) -> Binding<SpendAccountDraft> {
        Binding(
            get: { drafts.first { $0.id == id } ?? SpendAccountDraft() },
            set: { updated in
                guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
                drafts[index] = updated
            }
        )
    }

    private func save() {
        let rows = prepared
        let userId = accounts.first?.userId ?? LocalUser.id
        let alreadyPrimary = accounts.contains(where: \.isPrimary)
        for (index, row) in rows.enumerated() {
            let account = Account(
                userId: userId,
                accountNumber: row.last4,
                accountType: .checking,
                balance: 0,
                availableBalance: 0,
                nickname: "\(row.bank) · \(row.last4)",
                isPrimary: !alreadyPrimary && index == 0
            )
            account.bankName = row.bank
            context.insert(account)
        }
        do {
            try context.save()
            onFinished()
            if isAddingMore { dismiss() }
        } catch {
            message = "Those accounts could not be saved."
        }
    }
}

struct AuthenticatedHomeGate: View {
    @EnvironmentObject private var authenticationService: AuthenticationService
    @Query(sort: \Account.openedDate) private var accounts: [Account]
    var onAccountsChanged: () -> Void

    var body: some View {
        if authenticationService.isDecoySession || accounts.contains(where: \.isDeclaredSpendAccount) {
            MainTabView()
        } else {
            NavigationStack {
                SpendAccountSetupView(onFinished: onAccountsChanged)
            }
        }
    }
}

private struct SpendAccountDraft: Identifiable {
    let id = UUID()
    var bankName = ""
    var last4 = ""
}

private struct SpendAccountDraftCard: View {
    @Binding var draft: SpendAccountDraft
    var onRemove: (() -> Void)?

    private var suggestions: [String] {
        let query = draft.bankName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.count >= 1 else { return [] }
        if IndianBankCatalog.banks.contains(where: { $0.name.lowercased() == query }) { return [] }
        return Array(IndianBankCatalog.banks.map(\.name).filter { $0.lowercased().contains(query) }.prefix(5))
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Text("Account")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let onRemove {
                        Button("Remove", action: onRemove)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.bankDanger)
                    }
                }

                TextField("Bank name", text: $draft.bankName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.bankGroupedBackground, in: RoundedRectangle(cornerRadius: 12))

                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(suggestions, id: \.self) { name in
                            Button(name) { draft.bankName = name }
                                .font(.subheadline)
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.bankPrimary)
                        }
                    }
                }

                TextField("Last 4 digits", text: $draft.last4)
                    .keyboardType(.numberPad)
                    .onChange(of: draft.last4) { _, newValue in
                        let digits = String(newValue.filter(\.isNumber).prefix(4))
                        if digits != newValue { draft.last4 = digits }
                    }
                    .padding(12)
                    .background(Color.bankGroupedBackground, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(AppSpacing.lg)
        }
    }
}
