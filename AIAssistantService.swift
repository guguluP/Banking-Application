import Foundation
import FoundationModels

enum AIAssistantError: Error, LocalizedError {
    case unavailable
    case failed(String)
    
    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "AI is unavailable on this OS version."
        case .failed(let message):
            return message
        }
    }
}

final class AIAssistantService {
    static let shared = AIAssistantService()
    private init() {}
    
    func summarize(text: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else {
                // Apple Intelligence exists on this OS version but isn't
                // enabled/downloaded on this particular device (e.g. disabled
                // in Settings, or the model assets haven't finished
                // downloading) — degrade gracefully instead of failing.
                return makeLocalFallbackSummary(for: text)
            }
            let session = LanguageModelSession()
            let response = try await session.respond(
                to: "Summarize the following text in 3 concise bullet points. Avoid extraneous commentary.\n\nText:\n\(text)"
            )
            return response.content
        } else {
            return makeLocalFallbackSummary(for: text)
        }
    }

    /// Turns this week's category-level spending into a short, friendly,
    /// on-device summary using Apple Intelligence — e.g. "You spent mostly on
    /// dining and groceries this week, and you're on track against your
    /// available balance." Runs entirely on-device via Foundation Models; no
    /// transaction or balance data is sent anywhere.
    func spendingInsight(categories: [CategorySpending], totalAvailableBalance: Decimal) async throws -> String {
        guard !categories.isEmpty else { return "" }

        let summaryLines = categories.prefix(5).map { category in
            "- \(category.name): \(CurrencyFormatter.shared.string(from: category.amount))"
        }.joined(separator: "\n")

        let prompt = """
        You are a friendly banking assistant. In 1-2 short sentences, summarize this \
        week's spending by category for the user. Be warm and specific, mention the \
        top category, and do not repeat every number verbatim. Available balance is \
        \(CurrencyFormatter.shared.string(from: totalAvailableBalance)).

        If you address the user directly, greet them with "Dear Customer" — never \
        "Hello Friend", "Hi friend", or any other casual greeting.

        Spending by category:
        \(summaryLines)
        """

        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else {
                return makeLocalFallbackInsight(categories: categories)
            }
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return normalizeGreeting(in: response.content)
        } else {
            return makeLocalFallbackInsight(categories: categories)
        }
    }

    /// Safety net in case the on-device model ignores the prompt instruction
    /// and still opens with a casual "Hello Friend"-style greeting. Normalizes
    /// it to "Dear Customer" so the tone stays consistent regardless of what
    /// the model produces.
    private func normalizeGreeting(in text: String) -> String {
        let patterns = ["hello friend", "hi friend", "hey friend", "hello, friend", "hi, friend", "hey, friend"]
        var result = text
        for pattern in patterns {
            guard let range = result.range(of: pattern, options: [.caseInsensitive]) else { continue }
            result.replaceSubrange(range, with: "Dear Customer")
        }
        return result
    }
    
    private func makeLocalFallbackSummary(for text: String) -> String {
        let sentences = text
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: ".")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let top = sentences.prefix(3)
        if top.isEmpty { return "• (No content)" }
        return top.map { "• \($0)." }.joined(separator: "\n")
    }

    /// A simple, deterministic fallback used when Apple Intelligence isn't
    /// available (older device, unsupported OS, or the feature is turned off
    /// in Settings) so the insight card still shows something useful.
    private func makeLocalFallbackInsight(categories: [CategorySpending]) -> String {
        guard let top = categories.first else { return "" }
        let total = categories.reduce(Decimal(0)) { $0 + $1.amount }
        return "Your biggest spend this week was \(top.name) at \(CurrencyFormatter.shared.string(from: top.amount)), out of \(CurrencyFormatter.shared.string(from: total)) total."
    }
}
