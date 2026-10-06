import Foundation
import SwiftData

enum PaymentRail: String, Codable {
    case transfer
    case billPay
    case upi
    case scheduled
    case imported
}

enum PaymentFailure: Error, Equatable {
    case invalidAmount
    case invalidAccountNumber
    case sameAccount
    case insufficientFunds
    case accountNotMovable
    case overSingleCap
    case overPeriodLimit
    case payeeCoolingOff
    case movementBlocked
    case duplicate
    case saveFailed
    case notAuthenticated
}

struct PaymentLeg {
    var account: Account
    var transaction: Transaction
    var balanceBefore: Decimal
    var availableBefore: Decimal
}

struct PaymentReceipt {
    var reference: String
    var amount: Decimal
    var duplicate: Bool
}

/// One place that validates a payment, writes the ledger rows, credits an
/// owned destination, and rolls every leg back when the save fails.
@MainActor
enum TransactionService {
    static let singleTransferCap: Decimal = 10_000
    /// Test hook. The next `post` throws after applying in-memory legs so
    /// rollback can be asserted without a broken store.
    static var debugFailNextSave = false

    @discardableResult
    static func post(
        from account: Account,
        amount: Decimal,
        rail: PaymentRail,
        counterparty: String,
        description: String,
        category: String,
        recipientAccountNumber: String? = nil,
        externalRef: String? = nil,
        currency: String? = nil,
        entrySource: TransactionEntrySource = .system,
        merchant: String? = nil,
        occurredAt: Date = Date(),
        applyRoundUp: Bool = false,
        cashbackRate: Decimal = 0,
        requireSession: Bool = true,
        in context: ModelContext
    ) throws -> PaymentReceipt {
        if requireSession && !AuthenticationService.sessionIsLive {
            throw PaymentFailure.notAuthenticated
        }
        if AuthenticationService.movementBlocked {
            throw PaymentFailure.movementBlocked
        }

        let payee = counterparty.trimmingCharacters(in: .whitespacesAndNewlines)
        guard amount > 0 else { throw PaymentFailure.invalidAmount }

        if rail == .transfer {
            let number = (recipientAccountNumber ?? payee).trimmingCharacters(in: .whitespaces)
            guard Self.isAccountNumber(number) else { throw PaymentFailure.invalidAccountNumber }
            guard number != account.accountNumber else { throw PaymentFailure.sameAccount }
            guard amount <= singleTransferCap else { throw PaymentFailure.overSingleCap }
        }

        guard account.accountStatus == .active else { throw PaymentFailure.accountNotMovable }

        if let externalRef, !externalRef.isEmpty,
           existing(reference: externalRef, in: context) != nil {
            return PaymentReceipt(reference: externalRef, amount: amount, duplicate: true)
        }

        try enforceLimits(account: account, amount: amount, rail: rail, on: occurredAt, in: context)
        try enforceCooling(amount: amount, recipient: recipientAccountNumber ?? payee, rail: rail, in: context)

        let reference = externalRef?.isEmpty == false ? externalRef! : newReference()
        if existing(reference: reference, in: context) != nil {
            return PaymentReceipt(reference: reference, amount: amount, duplicate: true)
        }

        var spare: Decimal = 0
        if applyRoundUp && AppSettings.shared.isRoundUpEnabled {
            spare = roundUpSpare(for: amount)
        }
        let cashback = cashbackRate > 0 ? (amount * cashbackRate).rounded(places: 2) : 0
        let needed = amount + spare
        guard account.availableBalance + cashback >= needed else { throw PaymentFailure.insufficientFunds }

        var legs: [PaymentLeg] = []
        let debit = makeTransaction(
            account: account,
            type: .transferOrPayment(rail),
            amount: amount,
            description: description,
            counterparty: payee,
            category: category,
            reference: reference,
            rail: rail,
            currency: currency ?? account.currency,
            entrySource: entrySource,
            merchant: merchant,
            date: occurredAt,
            externalRef: externalRef
        )
        legs.append(apply(debit, to: account, delta: -amount, in: context))

        if spare > 0 {
            let roundUp = makeTransaction(
                account: account,
                type: .transfer,
                amount: spare,
                description: "Round-up savings",
                counterparty: nil,
                category: "Savings",
                reference: reference + "-R",
                rail: rail,
                currency: account.currency,
                entrySource: .system,
                merchant: nil,
                date: occurredAt,
                externalRef: nil
            )
            legs.append(apply(roundUp, to: account, delta: -spare, in: context))
            if let savings = ownSavings(excluding: account, in: context) {
                let credit = makeTransaction(
                    account: savings,
                    type: .deposit,
                    amount: spare,
                    description: "Round-up from \(account.accountNumber.suffix(4))",
                    counterparty: account.accountNumber,
                    category: "Savings",
                    reference: reference + "-RC",
                    rail: rail,
                    currency: savings.currency,
                    entrySource: .system,
                    merchant: nil,
                    date: occurredAt,
                    externalRef: nil
                )
                legs.append(apply(credit, to: savings, delta: spare, in: context))
            }
        }

        if rail == .transfer, let number = recipientAccountNumber?.trimmingCharacters(in: .whitespaces),
           let dest = lookupAccount(number: number, in: context), dest.id != account.id {
            guard dest.accountStatus != .closed else { throw PaymentFailure.accountNotMovable }
            let credit = makeTransaction(
                account: dest,
                type: .deposit,
                amount: amount,
                description: "Transfer from \(account.accountNumber.suffix(4))",
                counterparty: account.accountNumber,
                category: "Transfer",
                reference: reference + "-C",
                rail: rail,
                currency: dest.currency,
                entrySource: .system,
                merchant: nil,
                date: occurredAt,
                externalRef: nil
            )
            legs.append(apply(credit, to: dest, delta: amount, in: context))
        }

        if cashback > 0 {
            let credit = makeTransaction(
                account: account,
                type: .deposit,
                amount: cashback,
                description: "Cashback — \(payee)",
                counterparty: nil,
                category: "Cashback",
                reference: reference + "-B",
                rail: rail,
                currency: account.currency,
                entrySource: .system,
                merchant: nil,
                date: occurredAt,
                externalRef: nil
            )
            legs.append(apply(credit, to: account, delta: cashback, in: context))
        }

        if debugFailNextSave {
            debugFailNextSave = false
            rollback(legs, in: context)
            // Persist the undo before the caller reads relationships. SwiftData
            // keeps a deleted row in the inverse array until the context saves.
            try? context.save()
            throw PaymentFailure.saveFailed
        }

        do {
            try context.save()
        } catch {
            rollback(legs, in: context)
            try? context.save()
            throw PaymentFailure.saveFailed
        }

        SpendAlertCenter.evaluate(account: account, amount: amount, rail: rail)
        return PaymentReceipt(reference: reference, amount: amount, duplicate: false)
    }

    static func isAccountNumber(_ value: String) -> Bool {
        let cleaned = value.trimmingCharacters(in: .whitespaces)
        return (8...12).contains(cleaned.count) && cleaned.allSatisfy(\.isNumber)
    }

    /// Spare paise to the next multiple of ₹10. ₹12.50 → ₹7.50. An exact multiple spares nothing.
    static func roundUpSpare(for amount: Decimal) -> Decimal {
        var value = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        let ten = Decimal(10)
        let quotient = rounded / ten
        var q = quotient
        var qUp = Decimal()
        NSDecimalRound(&qUp, &q, 0, .up)
        let spare = (qUp * ten) - rounded
        return spare == 10 ? 0 : max(0, spare)
    }

    static func recompute(_ account: Account) {
        let net = (account.transactions ?? []).reduce(Decimal(0)) { partial, tx in
            guard tx.countsInLedger, tx.status == .completed else { return partial }
            return partial + (tx.isCredit ? tx.amount : -tx.amount)
        }
        account.balance = account.openingBalance + net
        let available = account.balance - account.reservedHold
        account.availableBalance = available > 0 ? available : 0
    }

    static func adoptLedgerBaselines(in context: ModelContext) {
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        for account in accounts where !account.usesLedgerBalance {
            account.openingBalance = account.balance
            account.reservedHold = max(0, account.balance - account.availableBalance)
            for tx in account.transactions ?? [] {
                tx.countsInLedger = false
            }
            account.usesLedgerBalance = true
        }
        try? context.save()
    }

    static func rollback(_ legs: [PaymentLeg], in context: ModelContext) {
        for leg in legs.reversed() {
            context.delete(leg.transaction)
            leg.account.balance = leg.balanceBefore
            leg.account.availableBalance = leg.availableBefore
        }
    }

    // MARK: - Private

    private static func apply(_ tx: Transaction, to account: Account, delta: Decimal, in context: ModelContext) -> PaymentLeg {
        let leg = PaymentLeg(account: account, transaction: tx, balanceBefore: account.balance, availableBefore: account.availableBalance)
        tx.account = account
        tx.countsInLedger = true
        context.insert(tx)
        account.balance += delta
        account.availableBalance += delta
        if account.availableBalance < 0 { account.availableBalance = 0 }
        return leg
    }

    private static func makeTransaction(
        account: Account,
        type: TransactionType,
        amount: Decimal,
        description: String,
        counterparty: String?,
        category: String,
        reference: String,
        rail: PaymentRail,
        currency: String,
        entrySource: TransactionEntrySource,
        merchant: String?,
        date: Date,
        externalRef: String?
    ) -> Transaction {
        let tx = Transaction(
            accountId: account.id,
            type: type,
            amount: amount,
            currency: currency,
            description: description,
            counterparty: counterparty,
            referenceNumber: reference,
            transactionDate: date,
            category: category,
            status: .completed,
            merchant: merchant,
            entrySource: entrySource
        )
        tx.railRaw = rail.rawValue
        tx.externalRef = externalRef
        tx.countsInLedger = true
        return tx
    }

    private static func existing(reference: String, in context: ModelContext) -> Transaction? {
        let ref = reference
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.referenceNumber == ref })
        return try? context.fetch(descriptor).first
    }

    private static func lookupAccount(number: String, in context: ModelContext) -> Account? {
        let needle = number
        let descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.accountNumber == needle })
        return try? context.fetch(descriptor).first
    }

    private static func ownSavings(excluding account: Account, in context: ModelContext) -> Account? {
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        return accounts.first { $0.id != account.id && $0.accountType == .savings && $0.accountStatus == .active }
    }

    private static func enforceLimits(account: Account, amount: Decimal, rail: PaymentRail, on date: Date, in context: ModelContext) throws {
        let settings = AppSettings.shared
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: date)
        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? startDay
        let rows = account.transactions ?? []
        let railName = rail.rawValue
        func spent(since: Date) -> Decimal {
            rows.filter { $0.railRaw == railName && $0.isDebit && $0.countsInLedger && $0.transactionDate >= since }
                .reduce(0) { $0 + $1.amount }
        }
        let (daily, monthly): (Decimal, Decimal) = switch rail {
        case .transfer, .scheduled: (settings.dailyTransferLimit, settings.monthlyTransferLimit)
        case .upi: (settings.dailyUPILimit, settings.monthlyUPILimit)
        case .billPay: (settings.dailyBillPayLimit, settings.monthlyBillPayLimit)
        case .imported: (settings.dailyUPILimit, settings.monthlyUPILimit)
        }
        if spent(since: startDay) + amount > daily || spent(since: startMonth) + amount > monthly {
            throw PaymentFailure.overPeriodLimit
        }
    }

    private static func enforceCooling(amount: Decimal, recipient: String, rail: PaymentRail, in context: ModelContext) throws {
        guard rail == .transfer || rail == .upi else { return }
        let settings = AppSettings.shared
        guard amount >= settings.coolingLargeAmount else { return }
        let cleaned = recipient.trimmingCharacters(in: .whitespaces)
        let own = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        if own.contains(where: { $0.accountNumber == cleaned }) { return }
        let beneficiaries = (try? context.fetch(FetchDescriptor<Beneficiary>())) ?? []
        let match = beneficiaries.first {
            $0.accountNumber == cleaned || $0.nickname.caseInsensitiveCompare(cleaned) == .orderedSame
        }
        let created = match?.createdAt ?? Date()
        let eligibleAt = created.addingTimeInterval(settings.payeeCoolingHours * 3600)
        if match == nil || eligibleAt > Date() {
            throw PaymentFailure.payeeCoolingOff
        }
    }

    private static func newReference() -> String {
        let raw = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return "BS-" + String(raw.prefix(16))
    }
}

private extension TransactionType {
    static func transferOrPayment(_ rail: PaymentRail) -> TransactionType {
        switch rail {
        case .transfer, .scheduled: return .transfer
        case .billPay, .upi, .imported: return .payment
        }
    }
}

extension Decimal {
    func rounded(places: Int) -> Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, places, .plain)
        return result
    }
}

enum SpendAlertCenter {
    @MainActor
    static func evaluate(account: Account, amount: Decimal, rail: PaymentRail) {
        let settings = AppSettings.shared
        guard settings.isLargeTransactionAlertsEnabled, amount >= settings.largeTransactionAmount else { return }
        NotificationService.shared.notifyTransaction(
            amount: amount,
            title: "Large \(rail.rawValue) payment",
            body: "\(CurrencyFormatter.shared.string(from: amount, currencyCode: account.currency)) left \(account.nickname ?? account.accountType.rawValue).",
            remainingBalance: account.availableBalance
        )
        SecurityLog.record(kind: "large_payment", detail: "\(rail.rawValue) \(amount)")
    }
}
