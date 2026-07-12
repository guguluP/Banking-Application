@preconcurrency import AppIntents
import Foundation

struct SummarizeTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize Text"
    static let description = IntentDescription("Summarize a passage into concise bullet points using on-device AI.")

    @Parameter(title: "Text", requestValueDialog: IntentDialog("What text would you like me to summarize?"))
    var text: String

    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        do {
            let result = try await AIAssistantService.shared.summarize(text: text)
            return .result(value: result)
        } catch {
            if let localized = error as? LocalizedError, let message = localized.errorDescription {
                return .result(value: "Summarization unavailable: \(message)")
            }
            return .result(value: "Summarization unavailable on this device.")
        }
    }
}
