import Foundation
import SwiftData

/// Runs scheduled and standing instructions that are due when the app launches.
/// This is a catch-up pass, not a background refresh.
@MainActor
enum ScheduledPaymentRunner {
    static func processDue(in context: ModelContext, now: Date = Date()) {
        let pending = InstructionStatus.scheduled.rawValue
        let descriptor = FetchDescriptor<ScheduledInstruction>(
            predicate: #Predicate { $0.statusRaw == pending }
        )
        let items = (try? context.fetch(descriptor)) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        for item in items where item.executeOn <= now {
            guard let account = accounts.first(where: { $0.id == item.fromAccountId }) else { continue }
            let payee = item.payeeName
            let isAccount = TransactionService.isAccountNumber(payee)
            do {
                _ = try TransactionService.post(
                    from: account,
                    amount: item.amount,
                    rail: isAccount ? .transfer : .scheduled,
                    counterparty: payee,
                    description: item.note.isEmpty ? "Scheduled payment to \(payee)" : item.note,
                    category: "Scheduled",
                    recipientAccountNumber: isAccount ? payee : nil,
                    externalRef: "sched-\(item.id)-\(Int(item.executeOn.timeIntervalSince1970))",
                    requireSession: false,
                    in: context
                )
                if item.isStandingInstruction {
                    item.executeOn = nextDate(from: item.executeOn, frequency: item.frequency)
                } else {
                    item.status = .completed
                }
                try? context.save()
            } catch {
                continue
            }
        }
    }

    private static func nextDate(from date: Date, frequency: InstructionFrequency) -> Date {
        let calendar = Calendar.current
        switch frequency {
        case .once: return date
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        }
    }
}
