import Foundation
import AppIntents
import SwiftData

struct ImportBankSMSIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Import Bank SMS"
    nonisolated static let description = IntentDescription("Record a bank payment SMS in BankSecure")
    nonisolated static let openAppWhenRun = false

    @Parameter(title: "Message")
    var text: String

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Import bank message \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let context = PersistenceController.shared.mainContext
        guard let row = BankImportPipeline.ingestSMS(text, in: context) else {
            return .result(value: "That message was ignored. BankSecure stores a hash of parsed payments, not OTP texts.")
        }
        switch row.status {
        case .posted:
            return .result(value: "Saved \(row.merchant) for \(row.amount).")
        case .pendingReview:
            return .result(value: "Needs review in the Track tab.")
        case .duplicate:
            return .result(value: "Already recorded.")
        case .rejected, .ignored:
            return .result(value: "Not imported.")
        }
    }
}
