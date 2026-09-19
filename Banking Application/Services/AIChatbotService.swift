import Foundation
import Combine
import FoundationModels

/// Read-only snapshot of the signed-in user's data that the chatbot is
/// allowed to reason about. Built fresh for every request from whatever the
/// view models currently hold in memory — nothing here is persisted by this
/// service, and nothing here ever leaves the device (no network call is made
/// by either the AFM path or the fallback path).
enum AssistantIntent: String {
    case balance, spend, search, transfer, bill, fd, loan, security, budget, greeting, forecast, unknown
}

struct AssistantAction: Equatable {
    enum Kind: String, Equatable {
        case transfer, billPay, openFD, requestMoney
    }
    var kind: Kind
    var amount: Decimal?
    var payee: String?
}

struct ChatbotContext {
    var firstName: String
    var accounts: [(name: String, type: String, balance: Decimal, availableBalance: Decimal)]
    var recentTransactions: [(description: String, amount: Decimal, isCredit: Bool, category: String?, date: Date)]
    var budgets: [(category: String, limit: Decimal)] = []
    var upcomingBills: [(name: String, due: Date, amount: Decimal)] = []
    var receiptNotes: [String] = []
    var conversationMemory: [(role: String, text: String)] = []

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
    @Published private(set) var lastAction: AssistantAction?

    private var session: Any?
    private var fallbackTurns: [(role: String, text: String)] = []

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
        fallbackTurns = []
        lastAction = nil
        refreshAvailability()
    }

    func spendingInsight(categories: [CategorySpending], totalAvailableBalance: Decimal) async throws -> String {
        guard !categories.isEmpty else { return "" }
        let summaryLines = categories.prefix(5).map { category in
            "- \(category.name): \(CurrencyFormatter.shared.string(from: category.amount))"
        }.joined(separator: "\n")
        let fallback: String = {
            guard let top = categories.first else { return "" }
            let total = categories.reduce(Decimal(0)) { $0 + $1.amount }
            return "Your biggest spend this week was \(top.name) at \(CurrencyFormatter.shared.string(from: top.amount)), out of \(CurrencyFormatter.shared.string(from: total)) total."
        }()
        let prompt = """
        You are a friendly banking assistant. In 1-2 short sentences, summarize this \
        week's spending. Mention the top category. Available balance is \
        \(CurrencyFormatter.shared.string(from: totalAvailableBalance)).
        Greet with "Dear Customer" if you greet at all.
        Spending:
        \(summaryLines)
        """
        if #available(iOS 26.0, *), case .available = SystemLanguageModel.default.availability {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content
        }
        return fallback
    }

    func reply(to userMessage: String, context: ChatbotContext) async -> String {
        let trimmed = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        lastAction = nil

        var ctx = context
        ctx.conversationMemory = fallbackTurns

        if #available(iOS 26.0, *), case .available = SystemLanguageModel.default.availability {
            do {
                let text = try await replyUsingAFM(trimmed, context: ctx)
                remember(user: trimmed, assistant: text)
                lastAction = extractAction(from: trimmed)
                return text
            } catch {
                let text = replyUsingLocalRules(trimmed, context: ctx)
                remember(user: trimmed, assistant: text)
                return text
            }
        } else {
            let text = replyUsingLocalRules(trimmed, context: ctx)
            remember(user: trimmed, assistant: text)
            return text
        }
    }

    private func remember(user: String, assistant: String) {
        fallbackTurns.append((role: "user", text: user))
        fallbackTurns.append((role: "assistant", text: assistant))
        if fallbackTurns.count > 8 {
            fallbackTurns.removeFirst(fallbackTurns.count - 8)
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

    private func classify(_ text: String) -> AssistantIntent {
        let t = text.lowercased()
        let ranked: [(AssistantIntent, [String])] = [
            (.budget, ["budget", "on track", "overspend", "limit"]),
            (.forecast, ["forecast", "cash flow", "will i have", "projected"]),
            (.search, ["show me", "what did i spend at", "restaurants", "filter"]),
            (.transfer, ["send money", "transfer", "pay "]),
            (.bill, ["bill", "electricity", "biller"]),
            (.fd, ["fixed deposit", " fd", "open fd"]),
            (.loan, ["loan", "emi"]),
            (.security, ["face id", "touch id", "passcode", "security"]),
            (.spend, ["spend", "spent", "expense"]),
            (.balance, ["balance", "how much do i have"]),
            (.greeting, ["hi", "hello", "hey"])
        ]
        for (intent, keys) in ranked {
            if keys.contains(where: { t.contains($0) }) { return intent }
        }
        return .unknown
    }

    private func extractAmount(from text: String) -> Decimal? {
        let pattern = #"(\d+(?:\.\d{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        return Decimal(string: String(text[range]))
    }

    private func extractAction(from userMessage: String) -> AssistantAction? {
        let intent = classify(userMessage)
        switch intent {
        case .transfer:
            return AssistantAction(kind: .transfer, amount: extractAmount(from: userMessage), payee: nil)
        case .bill:
            return AssistantAction(kind: .billPay, amount: extractAmount(from: userMessage), payee: nil)
        case .fd:
            return AssistantAction(kind: .openFD, amount: extractAmount(from: userMessage), payee: nil)
        default:
            return nil
        }
    }

    private func replyUsingLocalRules(_ userMessage: String, context: ChatbotContext) -> String {
        let text = userMessage.lowercased()
        lastAction = extractAction(from: userMessage)

        if text.contains("last month") || text.contains("what about") {
            if let prior = context.conversationMemory.last(where: { $0.role == "user" }) {
                return "Following up on \"\(prior.text)\": I can filter last month's activity from your on-device ledger. Ask me to show restaurants, groceries, or a merchant."
            }
        }

        switch classify(text) {
        case .budget:
            if context.budgets.isEmpty {
                return "Dear Customer, no budgets are set yet. Add category limits in Track and I'll tell you if you're on track."
            }
            let lines = context.budgets.map { "\($0.category): \(CurrencyFormatter.shared.string(from: $0.limit)) limit" }
            return "Dear Customer, here's your budget snapshot: " + lines.joined(separator: "; ") + "."
        case .forecast:
            return "Dear Customer, open Home for the 30-day cash-flow projection based on spending velocity and upcoming EMIs."
        case .search:
            return "Dear Customer, I can search your ledger. Try: show restaurants last month."
        default:
            break
        }

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

