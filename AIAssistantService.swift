import Foundation
import FoundationModels

public enum AIAssistantError: Error, LocalizedError {
    case unavailable
    case failed(String)
    
    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "AI is unavailable on this OS version."
        case .failed(let message):
            return message
        }
    }
}

public final class AIAssistantService {
    public static let shared = AIAssistantService()
    private init() {}
    
    public func summarize(text: String) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession()
            let prompt = Prompt("Summarize the following text in 3 concise bullet points. Avoid extraneous commentary.\n\nText:\n\(text)")
            let response = try await session.generateResponse(for: GenerateRequest(prompt: prompt))
            return response.content
        } else {
            throw AIAssistantError.unavailable
        }
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
}
