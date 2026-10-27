import XCTest
import SwiftData
@testable import Banking_Application

@MainActor
final class ScheduledPaymentRunnerTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try makeInMemoryContainer()
        AuthenticationService.sessionIsLive = true
        AuthenticationService.movementBlocked = false
    }

    override func tearDown() async throws {
        Ledger.debugFailNextCommit = false
        AuthenticationService.sessionIsLive = false
    }

    private func savedAccount(balance: Decimal) throws -> Account {
        let account = Account(userId: "test-user", accountNumber: "1000200040", accountType: .savings, balance: balance, availableBalance: balance)
        context.insert(account)
        try context.save()
        return account
    }

    private func instruction(from account: Account, amount: Decimal, due: Date, standing: Bool = false) throws -> ScheduledInstruction {
        let item = ScheduledInstruction(
            userId: "test-user",
            fromAccountId: account.id,
            payeeName: "Sample Utility",
            amount: amount,
            executeOn: due,
            frequency: standing ? .monthly : .once,
            isStandingInstruction: standing
        )
        context.insert(item)
        try context.save()
        return item
    }

    private func transactions() throws -> [Transaction] {
        try context.fetch(FetchDescriptor<Transaction>())
    }

    func testDueOneOffPaymentIsPaidOnceAndCompleted() throws {
        let account = try savedAccount(balance: 1_000)
        let item = try instruction(from: account, amount: 100, due: Date().addingTimeInterval(-3_600))

        ScheduledPaymentRunner.processDue(in: context)
        ScheduledPaymentRunner.processDue(in: context)

        XCTAssertEqual(item.status, .completed)
        XCTAssertEqual(account.balance, 900)
        XCTAssertEqual(try transactions().count, 1)
        XCTAssertEqual(try transactions().first?.externalRef?.hasPrefix("sched-\(item.id)-"), true)
    }

    func testFuturePaymentIsNotPaid() throws {
        let account = try savedAccount(balance: 1_000)
        let item = try instruction(from: account, amount: 100, due: Date().addingTimeInterval(86_400))
        ScheduledPaymentRunner.processDue(in: context)
        XCTAssertEqual(item.status, .scheduled)
        XCTAssertEqual(account.balance, 1_000)
    }

    func testStandingInstructionAdvancesIntoTheFuture() throws {
        let account = try savedAccount(balance: 1_000)
        let now = Date()
        let due = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let item = try instruction(from: account, amount: 100, due: due, standing: true)

        ScheduledPaymentRunner.processDue(in: context, now: now)

        XCTAssertEqual(item.status, .scheduled)
        XCTAssertGreaterThan(item.executeOn, now)
        XCTAssertEqual(account.balance, 900)

        // Nothing is due again until the new date.
        ScheduledPaymentRunner.processDue(in: context, now: now)
        XCTAssertEqual(account.balance, 900)
    }

    func testInsufficientFundsLeavesANoteAndNoDebit() throws {
        let account = try savedAccount(balance: 50)
        let item = try instruction(from: account, amount: 100, due: Date().addingTimeInterval(-3_600))

        ScheduledPaymentRunner.processDue(in: context)

        XCTAssertEqual(item.status, .scheduled)
        XCTAssertEqual(item.lastError, "Insufficient funds")
        XCTAssertEqual(account.balance, 50)
        XCTAssertTrue(try transactions().isEmpty)
    }
}

@MainActor
final class LoanCalculatorTests: XCTestCase {
    private func double(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }

    func testZeroRateSplitsPrincipalEvenly() {
        XCTAssertEqual(LoanCalculator.monthlyEMI(principal: 12_000, annualRatePercent: 0, months: 12), 1_000)
        XCTAssertEqual(LoanCalculator.totalInterest(principal: 12_000, annualRatePercent: 0, months: 12), 0)
    }

    func testStandardEMI() {
        // 1,00,000 at 12% p.a. over 12 months is ₹8,884.88 a month.
        let emi = LoanCalculator.monthlyEMI(principal: 100_000, annualRatePercent: 12, months: 12)
        XCTAssertEqual(double(emi), 8_884.88, accuracy: 0.005)
        let interest = LoanCalculator.totalInterest(principal: 100_000, annualRatePercent: 12, months: 12)
        XCTAssertEqual(double(interest), 6_618.56, accuracy: 0.05)
    }

    func testNonPositiveTenureReturnsPrincipal() {
        XCTAssertEqual(LoanCalculator.monthlyEMI(principal: 5_000, annualRatePercent: 10, months: 0), 5_000)
    }

    func testScheduleEndsAtZero() {
        let rows = LoanCalculator.amortizationSchedule(principal: 100_000, annualRatePercent: 12, months: 12)
        XCTAssertEqual(rows.count, 12)
        XCTAssertEqual(rows.last?.remainingBalance, 0)
        XCTAssertEqual(double(rows.first?.interestPortion ?? 0), 1_000, accuracy: 0.005)
        let principalPaid = rows.reduce(Decimal(0)) { $0 + $1.principalPortion }
        XCTAssertEqual(double(principalPaid), 100_000, accuracy: 0.01)
        XCTAssertTrue(LoanCalculator.amortizationSchedule(principal: 1_000, annualRatePercent: 10, months: 601).isEmpty)
    }

    func testMonthsToPayoff() {
        let emi = LoanCalculator.monthlyEMI(principal: 100_000, annualRatePercent: 12, months: 12)
        XCTAssertEqual(LoanCalculator.monthsToPayoff(balance: 100_000, monthlyRate: 0.01, emi: emi), 12)
        XCTAssertEqual(LoanCalculator.monthsToPayoff(balance: 1_000, monthlyRate: 0, emi: 300), 4)
        XCTAssertEqual(LoanCalculator.monthsToPayoff(balance: 0, monthlyRate: 0.01, emi: 300), 0)
    }

    func testPrepaymentShortensTenureAndSavesInterest() {
        let emi = LoanCalculator.monthlyEMI(principal: 100_000, annualRatePercent: 12, months: 12)
        let partial = LoanCalculator.prepaymentImpact(
            outstandingPrincipal: 100_000, annualRatePercent: 12, currentEMI: emi, prepaymentAmount: 30_000
        )
        // EMI ₹8,884.88. Without prepayment: 11 EMIs + a final ₹8,884.85 = ₹1,06,618.53 paid,
        // so ₹6,618.53 interest. With ₹70,000 left: 8 EMIs + a final ₹2,204.60 = ₹73,283.64
        // paid, so ₹3,283.64 interest. Saved ₹3,334.89 and 3 months.
        XCTAssertEqual(NSDecimalNumber(decimal: emi).doubleValue, 8884.88, accuracy: 0.001)
        XCTAssertEqual(partial.newRemainingMonths, 9)
        XCTAssertEqual(partial.monthsSaved, 3)
        XCTAssertEqual(partial.interestSaved, Decimal(string: "3334.89"))

        let full = LoanCalculator.prepaymentImpact(
            outstandingPrincipal: 100_000, annualRatePercent: 12, currentEMI: emi, prepaymentAmount: 100_000
        )
        XCTAssertEqual(full.newRemainingMonths, 0)
        XCTAssertEqual(full.monthsSaved, 12)
        XCTAssertEqual(full.interestSaved, Decimal(string: "6618.53"))
    }

    func testFixedEMIScheduleEndsWithAPartialInstalment() {
        let rows = LoanCalculator.fixedEMISchedule(balance: 70_000, annualRatePercent: 12, emi: Decimal(string: "8884.88")!)
        XCTAssertEqual(rows.count, 9)
        XCTAssertEqual(rows.last?.emi, Decimal(string: "2204.60"))
        XCTAssertEqual(rows.last?.remainingBalance, 0)
        // An EMI that never covers the interest has no schedule.
        XCTAssertTrue(LoanCalculator.fixedEMISchedule(balance: 100_000, annualRatePercent: 12, emi: 1_000).isEmpty)
    }

    func testZeroRatePrepaymentSavesMonthsButNoInterest() {
        let impact = LoanCalculator.prepaymentImpact(
            outstandingPrincipal: 1_200, annualRatePercent: 0, currentEMI: 100, prepaymentAmount: 300
        )
        XCTAssertEqual(impact.newRemainingMonths, 9)
        XCTAssertEqual(impact.monthsSaved, 3)
        XCTAssertEqual(impact.interestSaved, 0)
    }
}

@MainActor
final class AnalyticsTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try makeInMemoryContainer()
    }

    private func entry(_ amount: Decimal, _ type: TransactionType, on date: Date, category: String) -> Transaction {
        Transaction(accountId: "acct", type: type, amount: amount, description: "Sample", transactionDate: date, category: category)
    }

    func testMonthTotalsCountDebitsOnly() throws {
        let transactionViewModel = TransactionViewModel(modelContext: context, loadImmediately: false)
        let accountViewModel = AccountViewModel(modelContext: context, transactionViewModel: transactionViewModel)
        let tracker = ExpenseTrackerViewModel(modelContext: context, accountViewModel: accountViewModel, transactionViewModel: transactionViewModel)
        let analytics = ExpenseAnalyticsViewModel(tracker: tracker)

        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let lastMonth = calendar.date(byAdding: .day, value: -3, to: monthStart)!

        analytics.recompute(entries: [
            entry(100, .payment, on: now, category: "Food"),
            entry(50, .payment, on: now, category: "Travel"),
            entry(999, .deposit, on: now, category: "Salary"),
            entry(75, .payment, on: lastMonth, category: "Food")
        ])

        XCTAssertEqual(analytics.currentMonthTotal, 150)
        XCTAssertEqual(analytics.previousMonthTotal, 75)
        XCTAssertEqual(analytics.percentChange ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(Set(analytics.categorySlices.map(\.name)), ["Food", "Travel"])
        XCTAssertEqual(analytics.categorySlices.reduce(Decimal(0)) { $0 + $1.amount }, 150)
    }

    func testNoPreviousSpendMeansNoPercentChange() throws {
        let transactionViewModel = TransactionViewModel(modelContext: context, loadImmediately: false)
        let accountViewModel = AccountViewModel(modelContext: context, transactionViewModel: transactionViewModel)
        let tracker = ExpenseTrackerViewModel(modelContext: context, accountViewModel: accountViewModel, transactionViewModel: transactionViewModel)
        let analytics = ExpenseAnalyticsViewModel(tracker: tracker)
        analytics.recompute(entries: [entry(40, .payment, on: Date(), category: "Food")])
        XCTAssertEqual(analytics.currentMonthTotal, 40)
        XCTAssertNil(analytics.percentChange)
    }

    func testAnomalyFlagsALargeOneOffAndANewLocation() {
        var rows: [Transaction] = []
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        for _ in 0..<12 {
            let tx = entry(100, .payment, on: noon, category: "Food")
            tx.location = "Home Town"
            rows.append(tx)
        }
        let big = entry(5_000, .payment, on: noon, category: "Shopping")
        big.location = "Somewhere New"
        rows.append(big)

        let anomalies = FinancialIntelligenceService.detectAnomalies(transactions: rows)
        XCTAssertEqual(anomalies.map(\.transactionId), [big.id])
        XCTAssertTrue(anomalies.first?.reason.contains("new location: Somewhere New") ?? false)
    }
}
