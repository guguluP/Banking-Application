import Foundation
import SwiftData

@Model
nonisolated final class SecurityEvent {
    var id: String = UUID().uuidString
    var kind: String = ""
    var detail: String = ""
    var createdAt: Date = Date()

    init(kind: String, detail: String, createdAt: Date = Date()) {
        self.kind = kind
        self.detail = detail
        self.createdAt = createdAt
    }
}

@MainActor
enum SecurityLog {
    /// Events older than this are pruned. The activity screen shows at most
    /// `SecurityActivityView.displayLimit` rows anyway.
    static let retentionDays = 180
    private static var didPruneThisLaunch = false

    static func record(kind: String, detail: String, in context: ModelContext? = nil) {
        let ctx = context ?? PersistenceController.shared.mainContext
        ctx.insert(SecurityEvent(kind: kind, detail: detail))
        if !didPruneThisLaunch {
            didPruneThisLaunch = true
            prune(in: ctx)
        }
        Ledger.saveOrLog(ctx, "security event")
    }

    /// Deletes events older than `retentionDays`. Does not save.
    static func prune(in context: ModelContext, now: Date = Date()) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: now) else { return }
        try? context.delete(model: SecurityEvent.self, where: #Predicate<SecurityEvent> { $0.createdAt < cutoff })
    }
}
