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
    case destinationNotMovable
    case cardBlocked
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

        if rail == .transfer || rail == .scheduled {
            guard amount <= singleTransferCap else { throw PaymentFailure.overSingleCap }
        }

        if rail == .transfer {
            let number = (recipientAccountNumber ?? payee).trimmingCharacters(in: .whitespaces)
            guard Self.isAccountNumber(number) else { throw PaymentFailure.invalidAccountNumber }
            guard number != account.accountNumber else { throw PaymentFailure.sameAccount }
        }

        guard account.accountStatus == .active else { throw PaymentFailure.accountNotMovable }
        if rail == .upi || rail == .billPay {
            try enforceCard(in: context)
        }

        if let externalRef, !externalRef.isEmpty,
           existing(reference: externalRef, in: context) != nil {
            return PaymentReceipt(reference: externalRef, amount: amount, duplicate: true)
        }

        // One savings lookup serves both the spare amount and the round-up credit leg.
        let roundUpSavings = applyRoundUp ? roundUpDestination(for: amount, from: account, in: context) : nil
        let spare = roundUpSavings == nil ? 0 : roundUpSpare(for: amount)
        try enforceLimits(account: account, amount: amount + spare, rail: rail, on: occurredAt, in: context)
        try enforceCooling(amount: amount, recipient: recipientAccountNumber ?? payee, rail: rail, in: context)

        // A caller-supplied ref was checked above; a fresh UUID ref cannot already exist.
        let reference = externalRef?.isEmpty == false ? externalRef! : newReference()

        var internalDestination: Account?
        if rail == .transfer, let number = recipientAccountNumber?.trimmingCharacters(in: .whitespaces),
           let dest = lookupAccount(number: number, in: context), dest.id != account.id {
            guard dest.accountStatus == .active else { throw PaymentFailure.destinationNotMovable }
            internalDestination = dest
        }

        let cashback = cashbackRate > 0 ? (amount * cashbackRate).rounded(places: 2) : 0
        guard account.availableBalance >= amount + spare else { throw PaymentFailure.insufficientFunds }

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

        if spare > 0, let savings = roundUpSavings {
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

        if let dest = internalDestination {
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

        var reconciled: [String] = []
        for leg in legs where !reconciled.contains(leg.account.id) {
            reconciled.append(leg.account.id)
            reconcile(leg.account)
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

    static let accountNumberLength = 8...18

    static func isAccountNumber(_ value: String) -> Bool {
        let cleaned = value.trimmingCharacters(in: .whitespaces)
        return accountNumberLength.contains(cleaned.count) && cleaned.allSatisfy(\.isNumber)
    }

    /// Spare that will actually leave the source. Zero when round-up is off or there is no other active savings account to receive it.
    static func roundUpDebit(for amount: Decimal, from account: Account, in context: ModelContext) -> Decimal {
        roundUpDestination(for: amount, from: account, in: context) == nil ? 0 : roundUpSpare(for: amount)
    }

    /// The savings account that receives the spare, or nil when round-up is off, the
    /// amount spares nothing, or there is no other active savings account.
    private static func roundUpDestination(for amount: Decimal, from account: Account, in context: ModelContext) -> Account? {
        guard AppSettings.shared.isRoundUpEnabled, roundUpSpare(for: amount) > 0 else { return nil }
        return ownSavings(excluding: account, in: context)
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
        Ledger.apply(delta, to: account)
        return leg
    }

    /// Available balance is book balance minus the hold captured at adoption. Derived once after every leg so a mid-post floor cannot mint spendable money.
    private static func reconcile(_ account: Account) {
        let available = account.balance - account.reservedHold
        account.availableBalance = available > 0 ? available : 0
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
        var descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.referenceNumber == ref })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func lookupAccount(number: String, in context: ModelContext) -> Account? {
        let needle = number
        var descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.accountNumber == needle })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func ownSavings(excluding account: Account, in context: ModelContext) -> Account? {
        let excludedId = account.id
        let savings = AccountType.savings.rawValue
        let active = AccountStatus.active.rawValue
        var descriptor = FetchDescriptor<Account>(predicate: #Predicate {
            $0.id != excludedId && $0.accountTypeRaw == savings && $0.accountStatusRaw == active
        })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func enforceLimits(account: Account, amount: Decimal, rail: PaymentRail, on date: Date, in context: ModelContext) throws {
        let settings = AppSettings.shared
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: date)
        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? startDay
        if rail == .imported { return }
        // Only this month's ledger rows matter, so fetch by date instead of walking every row on the account.
        let accountId = account.id
        let monthRows = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate {
            $0.transactionDate >= startMonth && $0.countsInLedger == true
        }))) ?? []
        let rows = monthRows.filter { $0.account?.id == accountId }
        let rails = limitRails(for: rail)
        func spent(since: Date) -> Decimal {
            rows.filter { rails.contains($0.railRaw) && $0.isDebit && $0.countsInLedger && $0.transactionDate >= since }
                .reduce(0) { $0 + $1.amount }
        }
        let (daily, monthly): (Decimal, Decimal) = switch rail {
        case .transfer, .scheduled: (settings.dailyTransferLimit, settings.monthlyTransferLimit)
        case .upi: (settings.dailyUPILimit, settings.monthlyUPILimit)
        case .billPay: (settings.dailyBillPayLimit, settings.monthlyBillPayLimit)
        case .imported: (0, 0)
        }
        if spent(since: startDay) + amount > daily || spent(since: startMonth) + amount > monthly {
            throw PaymentFailure.overPeriodLimit
        }
    }

    private static func limitRails(for rail: PaymentRail) -> Set<String> {
        switch rail {
        case .transfer, .scheduled:
            return [PaymentRail.transfer.rawValue, PaymentRail.scheduled.rawValue]
        case .upi:
            return [PaymentRail.upi.rawValue]
        case .billPay:
            return [PaymentRail.billPay.rawValue]
        case .imported:
            return []
        }
    }

    private static func enforceCard(in context: ModelContext) throws {
        let cards = (try? context.fetch(FetchDescriptor<Card>())) ?? []
        guard !cards.isEmpty else { return }
        let canPay = cards.contains { $0.cardStatus == .active && $0.isOnlineTransactionsEnabled }
        if !canPay { throw PaymentFailure.cardBlocked }
    }

    private static func enforceCooling(amount: Decimal, recipient: String, rail: PaymentRail, in context: ModelContext) throws {
        guard rail == .transfer || rail == .upi || rail == .scheduled else { return }
        let settings = AppSettings.shared
        guard amount >= settings.coolingLargeAmount else { return }
        let cleaned = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        if lookupAccount(number: cleaned, in: context) != nil { return }
        let beneficiaries = (try? context.fetch(FetchDescriptor<Beneficiary>())) ?? []
        let match = beneficiaries.first { beneficiary in
            if !beneficiary.accountNumber.isEmpty && beneficiary.accountNumber == cleaned { return true }
            let vpa = beneficiary.upiId.trimmingCharacters(in: .whitespacesAndNewlines)
            return !vpa.isEmpty && vpa.caseInsensitiveCompare(cleaned) == .orderedSame
        }
        guard let match else { throw PaymentFailure.payeeCoolingOff }
        let eligibleAt = match.createdAt.addingTimeInterval(settings.payeeCoolingHours * 3600)
        if eligibleAt > Date() {
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
