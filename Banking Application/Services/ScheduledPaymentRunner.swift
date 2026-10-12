import Foundation
import SwiftData

/// Catch-up for due scheduled and standing instructions.
/// A standing instruction is debited once, then its next date moves into the future.
@MainActor
enum ScheduledPaymentRunner {
    static func processDue(in context: ModelContext, now: Date = Date()) {
        let pending = InstructionStatus.scheduled.rawValue
        let descriptor = FetchDescriptor<ScheduledInstruction>(
            predicate: #Predicate { $0.statusRaw == pending }
        )
        let items = (try? context.fetch(descriptor)) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let retryWindow: TimeInterval = 12 * 60 * 60
        for item in items where item.executeOn <= now {
            if !item.lastError.isEmpty, now.timeIntervalSince(item.lastAttempt) < retryWindow {
                continue
            }
            guard let account = accounts.first(where: { $0.id == item.fromAccountId }) else { continue }
            let payee = item.payeeName
            let isAccount = TransactionService.isAccountNumber(payee)
            let due = item.executeOn
            do {
                _ = try TransactionService.post(
                    from: account,
                    amount: item.amount,
                    rail: isAccount ? .transfer : .scheduled,
                    counterparty: payee,
                    description: item.note.isEmpty ? "Scheduled payment to \(payee)" : item.note,
                    category: "Scheduled",
                    recipientAccountNumber: isAccount ? payee : nil,
                    externalRef: "sched-\(item.id)-\(Int(due.timeIntervalSince1970))",
                    requireSession: false,
                    in: context
                )
                item.lastError = ""
                if item.isStandingInstruction {
                    advanceUntilFuture(item, now: now)
                } else {
                    item.status = .completed
                }
                try? context.save()
            } catch let failure as PaymentFailure {
                item.lastError = failureNote(failure)
                item.lastAttempt = now
                item.status = .scheduled
                try? context.save()
            } catch {
                continue
            }
        }
    }

    private static func advanceUntilFuture(_ item: ScheduledInstruction, now: Date) {
        let calendar = Calendar.current
        if item.scheduledDay == 0 {
            item.scheduledDay = calendar.component(.day, from: item.executeOn)
        }
        var cursor = item.executeOn
        for _ in 0..<600 {
            let stepped = nextDate(from: cursor, frequency: item.frequency, scheduledDay: item.scheduledDay, calendar: calendar)
            if stepped <= cursor { break }
            cursor = stepped
            if cursor > now { break }
        }
        if cursor > item.executeOn {
            item.executeOn = cursor
        }
    }

    private static func nextDate(
        from date: Date,
        frequency: InstructionFrequency,
        scheduledDay: Int,
        calendar: Calendar
    ) -> Date {
        switch frequency {
        case .once:
            return date
        case .weekly:
            guard let raw = calendar.date(byAdding: .day, value: 7, to: date) else { return date }
            return atNine(raw, calendar: calendar)
        case .monthly:
            let preferred = scheduledDay > 0 ? scheduledDay : calendar.component(.day, from: date)
            let parts = calendar.dateComponents([.year, .month], from: date)
            var anchor = DateComponents()
            anchor.year = parts.year
            anchor.month = parts.month
            anchor.day = 1
            anchor.hour = 9
            guard let monthStart = calendar.date(from: anchor),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                return date
            }
            let length = calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 28
            let day = min(max(preferred, 1), length)
            var target = calendar.dateComponents([.year, .month], from: nextMonth)
            target.day = day
            target.hour = 9
            target.minute = 0
            target.second = 0
            return calendar.date(from: target) ?? nextMonth
        }
    }

    private static func atNine(_ date: Date, calendar: Calendar) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: date)
        parts.hour = 9
        parts.minute = 0
        parts.second = 0
        return calendar.date(from: parts) ?? date
    }

    private static func failureNote(_ failure: PaymentFailure) -> String {
        switch failure {
        case .insufficientFunds: return "Insufficient funds"
        case .overSingleCap: return "Above the transfer cap"
        case .overPeriodLimit: return "Above the period limit"
        case .payeeCoolingOff: return "Payee cooling off"
        case .accountNotMovable: return "Account cannot send"
        case .destinationNotMovable: return "Destination cannot receive"
        case .movementBlocked: return "Could not send"
        case .notAuthenticated: return "Could not send"
        case .invalidAmount: return "Invalid amount"
        case .invalidAccountNumber: return "Invalid account number"
        case .sameAccount: return "Same account"
        case .duplicate: return "Already posted"
        case .saveFailed: return "Could not save"
        case .cardBlocked: return "Card blocked"
        }
    }
}
