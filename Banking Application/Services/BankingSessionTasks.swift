import Foundation
import SwiftData

/// Money movement and import catch-up. Runs only after a real unlock.
@MainActor
enum BankingSessionTasks {
    static func runAfterUnlock(in context: ModelContext) {
        guard AuthenticationService.sessionIsLive && !AuthenticationService.movementBlocked else { return }
        ScheduledPaymentRunner.processDue(in: context)
        BankImportPipeline.ingestCapturedSMS(in: context)
        DepositService.processMatured(in: context)
    }
}
