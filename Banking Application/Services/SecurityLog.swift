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
    static func record(kind: String, detail: String, in context: ModelContext? = nil) {
        let ctx = context ?? PersistenceController.shared.mainContext
        ctx.insert(SecurityEvent(kind: kind, detail: detail))
        try? ctx.save()
    }
}
