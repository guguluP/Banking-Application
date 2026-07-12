import SwiftUI
import SwiftData

struct ChatbotView: View {
    @EnvironmentObject var authenticationService: AuthenticationService
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @StateObject private var chatbot = AIChatbotService.shared

    @State private var messages: [ChatMessage] = []
    @State private var draft: String = ""
    @State private var isThinking = false
    @FocusState private var inputFocused: Bool

    private let suggestedPrompts = [
        "What's my balance?",
        "What did I spend recently?",
        "How do I send money?"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: AppSpacing.md) {
                            if messages.isEmpty {
                                emptyState
                            }
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                            if isThinking {
                                HStack(spacing: AppSpacing.sm) {
                                    ProgressView()
                                    Text("Thinking…")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, AppSpacing.md)
                    }
                    .onChange(of: messages.count) {
                        guard let last = messages.last else { return }
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                inputBar
            }
            .navigationTitle("Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Assistant")
                            .font(.headline)
                        Text(chatbot.isUsingOnDeviceModel ? "On-device AI" : "On-device assistant")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                chatbot.resetConversation()
            }
        }
        .swipeDownToDismiss()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Ask me about your accounts")
                .font(.headline)
                .padding(.horizontal)

            Text("Everything here runs on your device — nothing you ask is sent anywhere.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(spacing: AppSpacing.sm) {
                ForEach(suggestedPrompts, id: \.self) { prompt in
                    Button(action: { send(prompt) }) {
                        HStack {
                            Text(prompt)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .glassControl(cornerRadius: AppTheme.CornerRadius.large, interactive: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, AppSpacing.lg)
    }

    private var inputBar: some View {
        HStack(spacing: AppSpacing.sm) {
            TextField("Ask about your account…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                .focused($inputFocused)
                .lineLimit(1...3)
                .padding(.vertical, AppSpacing.sm)
                .padding(.horizontal, AppSpacing.md)
                .glassControl(cornerRadius: AppTheme.CornerRadius.pill)
                .onSubmit { send(draft) }

            Button(action: { send(draft) }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : Color.bankPrimary)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
        }
        .padding()
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        HapticFeedbackService.shared.lightImpact()
        messages.append(ChatMessage(role: .user, text: trimmed))
        draft = ""
        isThinking = true

        let context = buildContext()

        Task {
            let reply = await chatbot.reply(to: trimmed, context: context)
            await MainActor.run {
                isThinking = false
                messages.append(ChatMessage(role: .assistant, text: reply))
            }
        }
    }

    private func buildContext() -> ChatbotContext {
        let accounts = accountViewModel.accounts.map {
            (name: $0.nickname ?? $0.accountType.rawValue, type: $0.accountType.rawValue, balance: $0.balance, availableBalance: $0.availableBalance)
        }
        let transactions = transactionViewModel.recentTransactions.map {
            (description: $0.description, amount: abs($0.amount), isCredit: $0.isCredit, category: $0.category, date: $0.transactionDate)
        }
        return ChatbotContext(
            firstName: authenticationService.user?.firstName ?? "there",
            accounts: accounts,
            recentTransactions: transactions
        )
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubble
            }
        }
        .padding(.horizontal)
    }

    private var bubble: some View {
        Text(message.text)
            .font(.subheadline)
            .foregroundColor(message.role == .user ? .white : .primary)
            .padding(.vertical, AppSpacing.sm)
            .padding(.horizontal, AppSpacing.md)
            .background(
                Group {
                    if message.role == .user {
                        Color.bankPrimary
                    } else {
                        Color(UIColor.secondarySystemBackground)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous))
    }
}

struct ChatbotView_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.preview
        let context = container.mainContext
        let transactionViewModel = TransactionViewModel(modelContext: context)
        let accountViewModel = AccountViewModel(modelContext: context, transactionViewModel: transactionViewModel)
        return ChatbotView()
            .environmentObject(AuthenticationService())
            .environmentObject(accountViewModel)
            .environmentObject(transactionViewModel)
    }
}
