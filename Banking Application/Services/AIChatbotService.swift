import Foundation
import Combine
import FoundationModels

/// Read-only snapshot of the signed-in user's data that the chatbot is
/// allowed to reason about. Built fresh for every request from whatever the
/// view models currently hold in memory — nothing here is persisted by this
/// service, and nothing here ever leaves the device (no network call is made
/// by either the AFM path or the fallback path).
struct ChatbotContext {
    var firstName: String
    var accounts: [(name: String, type: String, balance: Decimal, availableBalance: Decimal)]
    var recentTransactions: [(description: String, amount: Decimal, isCredit: Bool, category: String?, date: Date)]

    var totalAvailableBalance: Decimal {
        accounts.reduce(Decimal(0)) { $0 + $1.availableBalance }
    }
}

/// Powers the in-app "Ask BankSecure" chatbot.
///
/// Two response paths, both 100% on-device:
///  1. **Apple Foundation Models (AFM / Apple Intelligence)** — used whenever
///     `SystemLanguageModel.default.availability` reports `.available`. Gives
///     natural, multi-turn conversational answers grounded in the account
///     context we pass in the prompt.
///  2. **Local rule-based fallback** — used on any device/OS where Apple
///     Intelligence isn't available (older hardware, iOS < 26, the feature
///     turned off in Settings, or the model assets not yet downloaded). This
///     is *not* a "please enable Apple Intelligence" dead end: it actually
///     answers the common questions (balances, recent spending, top
///     category, help finding a feature) directly from local data, so the
///     chatbot works on every device.
@MainActor
final class AIChatbotService: ObservableObject {
    static let shared = AIChatbotService()

    /// Whether the AFM-backed path is available on this device right now.
    /// Views can use this to show a small "on-device AI" vs "offline
    /// assistant" indicator if desired, but it never gates whether the
    /// chatbot can be used at all.
    @Published private(set) var isUsingOnDeviceModel: Bool = false

    private var session: Any? // LanguageModelSession, boxed to avoid an iOS-version-gated stored property type.

    private init() {
        refreshAvailability()
    }

    private func refreshAvailability() {
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                isUsingOnDeviceModel = true
                return
            }
        }
        isUsingOnDeviceModel = false
    }

    /// Starts (or restarts) a fresh conversation. Call this when the chat
    /// sheet is opened so earlier unrelated turns don't bleed into a new
    /// session.
    func resetConversation() {
        session = nil
        refreshAvailability()
    }

    /// Sends one user message and returns the assistant's reply.
    func reply(to userMessage: String, context: ChatbotContext) async -> String {
        let trimmed = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if #available(iOS 26.0, *), case .available = SystemLanguageModel.default.availability {
            do {
                return try await replyUsingAFM(trimmed, context: context)
            } catch {
                // Model call failed at runtime (e.g. guardrail rejection,
                // transient session error) — degrade gracefully rather than
                // showing an error bubble in a banking app.
                return replyUsingLocalRules(trimmed, context: context)
            }
        } else {
            return replyUsingLocalRules(trimmed, context: context)
        }
    }

    // MARK: - AFM (on-device Apple Intelligence) path

    @available(iOS 26.0, *)
    private func replyUsingAFM(_ userMessage: String, context: ChatbotContext) async throws -> String {
        let activeSession: LanguageModelSession
        if let existing = session as? LanguageModelSession {
            activeSession = existing
        } else {
            let instructions = """
            You are the in-app assistant for BankSecure, a banking app. Answer \
            the customer's question in 1-3 short sentences, in plain language, \
            using ONLY the account information provided to you in each message. \
            Never invent numbers. If you don't have enough information to answer, \
            say so and suggest which screen in the app has it (Accounts, \
            Transfer, Payments, or Profile). Never ask for or reference full \
            card numbers, passwords, or OTPs. If addressing the customer by a \
            salutation, use "Dear Customer", never "Hello Friend".
            """
            activeSession = LanguageModelSession(instructions: instructions)
            session = activeSession
        }

        let prompt = """
        Account context (private, on-device only):
        \(Self.formatContext(context))

        Customer question: \(userMessage)
        """
        let response = try await activeSession.respond(to: prompt)
        return response.content
    }

    // MARK: - Local rule-based fallback (works on every device)

    private func replyUsingLocalRules(_ userMessage: String, context: ChatbotContext) -> String {
        let text = userMessage.lowercased()

        if text.contains("balance") {
            let formatted = CurrencyFormatter.shared.string(from: context.totalAvailableBalance)
            if context.accounts.count > 1 {
                let breakdown = context.accounts
                    .map { "\($0.name): \(CurrencyFormatter.shared.string(from: $0.availableBalance))" }
                    .joined(separator: ", ")
                return "Dear Customer, your total available balance is \(formatted) across \(context.accounts.count) accounts (\(breakdown))."
            }
            return "Dear Customer, your available balance is \(formatted)."
        }

        if text.contains("spend") || text.contains("spent") || text.contains("expense") {
            let debits = context.recentTransactions.filter { !$0.isCredit }
            guard !debits.isEmpty else {
                return "Dear Customer, I don't see any recent spending to summarize yet."
            }
            let total = debits.reduce(Decimal(0)) { $0 + $1.amount }
            let byCategory = Dictionary(grouping: debits, by: { $0.category ?? "Other" })
                .mapValues { $0.reduce(Decimal(0)) { $0 + $1.amount } }
            if let top = byCategory.max(by: { $0.value < $1.value }) {
                return "Dear Customer, you've spent \(CurrencyFormatter.shared.string(from: total)) recently, mostly on \(top.key) (\(CurrencyFormatter.shared.string(from: top.value)))."
            }
            return "Dear Customer, you've spent \(CurrencyFormatter.shared.string(from: total)) recently."
        }

        if text.contains("last transaction") || text.contains("recent transaction") || text.contains("latest transaction") {
            guard let latest = context.recentTransactions.first else {
                return "Dear Customer, I don't see any recent transactions yet."
            }
            let sign = latest.isCredit ? "credited" : "debited"
            return "Dear Customer, your most recent transaction was \(CurrencyFormatter.shared.string(from: latest.amount)) \(sign) for \(latest.description)."
        }

        if text.contains("send money") || text.contains("transfer") {
            return "Dear Customer, you can send money from the Transfer tab — pick an account and a payee, or add a new one."
        }

        if text.contains("scan") || text.contains("qr") || text.contains("upi") {
            return "Dear Customer, the Payments tab has Scan & Pay for UPI QR codes, plus bill pay."
        }

        if text.contains("bill") {
            return "Dear Customer, you can pay bills from the Payments tab under Pay Bills."
        }

        if text.contains("loan") {
            return "Dear Customer, loan details and prepayment options are on the Loans screen, reachable from your Accounts tab."
        }

        if text.contains("fixed deposit") || text.contains(" fd") || text.hasPrefix("fd") {
            return "Dear Customer, you can open or review Fixed Deposits from the Accounts tab."
        }

        if text.contains("face id") || text.contains("touch id") || text.contains("passcode") || text.contains("security") {
            return "Dear Customer, you can manage Face ID/Touch ID and your passcode under Profile > Privacy & Security."
        }

        if text.contains("hi") || text.contains("hello") || text.contains("hey") {
            return "Dear Customer, how can I help with your account today?"
        }

        return "Dear Customer, I can help with balances, recent spending, transfers, bill pay, and loans. Could you tell me a bit more about what you need?"
    }

    private static func formatContext(_ context: ChatbotContext) -> String {
        let accountsText = context.accounts
            .map { "- \($0.name) (\($0.type)): balance \(CurrencyFormatter.shared.string(from: $0.balance)), available \(CurrencyFormatter.shared.string(from: $0.availableBalance))" }
            .joined(separator: "\n")

        let transactionsText = context.recentTransactions.prefix(10)
            .map { "- \($0.isCredit ? "+" : "-")\(CurrencyFormatter.shared.string(from: $0.amount)) \($0.description) (\($0.category ?? "Other"))" }
            .joined(separator: "\n")

        return """
        Customer first name: \(context.firstName)
        Accounts:
        \(accountsText.isEmpty ? "(none)" : accountsText)
        Recent transactions:
        \(transactionsText.isEmpty ? "(none)" : transactionsText)
        """
    }
}
