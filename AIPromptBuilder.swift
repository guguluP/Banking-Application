import Foundation

// A small utility to build consistent prompts for the AI summarizer.
// Keeping this separate makes it easy to test deterministically.

public struct AIPromptBuilder {
    public init() {}

    public func summarizePrompt(for text: String, bulletCount: Int = 3) -> String {
        let clamped = max(1, min(6, bulletCount))
        return """
        Summarize the following text in \(clamped) concise bullet points. Avoid extraneous commentary.

        Text:
        \(text)
        """
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
