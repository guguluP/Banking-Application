import Foundation

/// Builds consistent prompts for the on-device summarizer.
struct AIPromptBuilder {
    func summarizePrompt(for text: String, bulletCount: Int = 3) -> String {
        let clamped = max(1, min(6, bulletCount))
        return """
        Summarize the following text in \(clamped) concise bullet points. Avoid extraneous commentary.

        Text:
        \(text)
        """
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
