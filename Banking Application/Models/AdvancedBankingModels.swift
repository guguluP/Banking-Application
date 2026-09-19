import Foundation
import SwiftData

enum InstructionFrequency: String, Codable, CaseIterable {
    case once = "Once"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

enum InstructionStatus: String, Codable {
    case scheduled = "Scheduled"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

@Model
nonisolated final class ScheduledInstruction {
    var id: String = UUID().uuidString
    var userId: String = ""
    var fromAccountId: String = ""
    var payeeName: String = ""
    var amount: Decimal = 0
    var currency: String = "INR"
    var note: String = ""
    var executeOn: Date = Date()
    var frequencyRaw: String = InstructionFrequency.once.rawValue
    var statusRaw: String = InstructionStatus.scheduled.rawValue
    var isStandingInstruction: Bool = false
    var createdAt: Date = Date()

    var frequency: InstructionFrequency {
        get { InstructionFrequency(rawValue: frequencyRaw) ?? .once }
        set { frequencyRaw = newValue.rawValue }
    }
    var status: InstructionStatus {
        get { InstructionStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }

    init(
        userId: String,
        fromAccountId: String,
        payeeName: String,
        amount: Decimal,
        executeOn: Date,
        frequency: InstructionFrequency = .once,
        isStandingInstruction: Bool = false,
        note: String = ""
    ) {
        self.userId = userId
        self.fromAccountId = fromAccountId
        self.payeeName = payeeName
        self.amount = amount
        self.executeOn = executeOn
        self.frequencyRaw = frequency.rawValue
        self.isStandingInstruction = isStandingInstruction
        self.note = note
    }
}

@Model
nonisolated final class SavingsGoal {
    var id: String = UUID().uuidString
    var userId: String = ""
    var name: String = ""
    var targetAmount: Decimal = 0
    var currentAmount: Decimal = 0
    var targetDate: Date = Date()
    var linkedFDId: String?
    var createdAt: Date = Date()

    init(userId: String, name: String, targetAmount: Decimal, targetDate: Date, currentAmount: Decimal = 0) {
        self.userId = userId
        self.name = name
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.currentAmount = currentAmount
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1, NSDecimalNumber(decimal: currentAmount / targetAmount).doubleValue)
    }
}

@Model
nonisolated final class Envelope {
    var id: String = UUID().uuidString
    var userId: String = ""
    var name: String = ""
    var allocated: Decimal = 0
    var spent: Decimal = 0
    var createdAt: Date = Date()

    init(userId: String, name: String, allocated: Decimal) {
        self.userId = userId
        self.name = name
        self.allocated = allocated
    }

    var remaining: Decimal { allocated - spent }
}

@Model
nonisolated final class MoneyRequest {
    var id: String = UUID().uuidString
    var userId: String = ""
    var fromName: String = ""
    var amount: Decimal = 0
    var note: String = ""
    var isCollect: Bool = true
    var isSplit: Bool = false
    var splitNamesCSV: String = ""
    var statusRaw: String = "Pending"
    var createdAt: Date = Date()

    init(userId: String, fromName: String, amount: Decimal, note: String, isCollect: Bool = true, isSplit: Bool = false, splitNamesCSV: String = "") {
        self.userId = userId
        self.fromName = fromName
        self.amount = amount
        self.note = note
        self.isCollect = isCollect
        self.isSplit = isSplit
        self.splitNamesCSV = splitNamesCSV
    }
}

@Model
nonisolated final class TransactionDispute {
    var id: String = UUID().uuidString
    var userId: String = ""
    var transactionId: String = ""
    var reason: String = ""
    var details: String = ""
    var statusRaw: String = "Submitted"
    var createdAt: Date = Date()

    init(userId: String, transactionId: String, reason: String, details: String) {
        self.userId = userId
        self.transactionId = transactionId
        self.reason = reason
        self.details = details
    }
}

@Model
nonisolated final class DeviceSession {
    var id: String = UUID().uuidString
    var userId: String = ""
    var deviceName: String = ""
    var platform: String = ""
    var lastActive: Date = Date()
    var isCurrent: Bool = false

    init(userId: String, deviceName: String, platform: String, isCurrent: Bool) {
        self.userId = userId
        self.deviceName = deviceName
        self.platform = platform
        self.isCurrent = isCurrent
        self.lastActive = Date()
    }
}

@Model
nonisolated final class VaultDocument {
    var id: String = UUID().uuidString
    var userId: String = ""
    var title: String = ""
    var kind: String = "KYC"
    var notes: String = ""
    var createdAt: Date = Date()

    init(userId: String, title: String, kind: String, notes: String = "") {
        self.userId = userId
        self.title = title
        self.kind = kind
        self.notes = notes
    }
}

@Model
nonisolated final class VirtualCard {
    var id: String = UUID().uuidString
    var userId: String = ""
    var lastFour: String = "0000"
    var merchantLock: String = ""
    var isSingleUse: Bool = true
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(userId: String, lastFour: String, merchantLock: String, isSingleUse: Bool) {
        self.userId = userId
        self.lastFour = lastFour
        self.merchantLock = merchantLock
        self.isSingleUse = isSingleUse
    }
}

@Model
nonisolated final class NetWorthSnapshot {
    var id: String = UUID().uuidString
    var userId: String = ""
    var value: Decimal = 0
    var capturedAt: Date = Date()

    init(userId: String, value: Decimal) {
        self.userId = userId
        self.value = value
        self.capturedAt = Date()
    }
}
