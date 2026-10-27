import XCTest
import SwiftData
import SwiftUI
@testable import Banking_Application

@MainActor
final class LedgerAndDepositTests: XCTestCase {
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
        let account = Account(userId: "test-user", accountNumber: "1000200030", accountType: .savings, balance: balance, availableBalance: balance)
        context.insert(account)
        try context.save()
        return account
    }

    private func transactions() throws -> [Banking_Application.Transaction] {
        try context.fetch(FetchDescriptor<Banking_Application.Transaction>())
    }

    // MARK: Ledger

    func testApplyMovesBothBalances() throws {
        let account = try savedAccount(balance: 100)
        Ledger.apply(-30, to: account)
        XCTAssertEqual(account.balance, 70)
        XCTAssertEqual(account.availableBalance, 70)
        Ledger.apply(5, to: account)
        XCTAssertEqual(account.balance, 75)
    }

    func testCommitSavesOnSuccess() throws {
        let account = try savedAccount(balance: 100)
        try Ledger.commit(context, touching: [account]) {
            Ledger.apply(-40, to: account)
            context.insert(Banking_Application.Transaction(accountId: account.id, type: .payment, amount: 40, description: "Sample", transactionDate: Date(), category: "Test"))
        }
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(account.balance, 60)
        XCTAssertEqual(try transactions().count, 1)
    }

    func testFailedCommitRestoresBalancesAndDropsInserts() throws {
        let account = try savedAccount(balance: 100)
        XCTAssertThrowsError(try Ledger.commit(context, touching: [account]) {
            Ledger.apply(-40, to: account)
            context.insert(Banking_Application.Transaction(accountId: account.id, type: .payment, amount: 40, description: "Sample", transactionDate: Date(), category: "Test"))
            Ledger.debugFailNextCommit = true
        })
        XCTAssertEqual(account.balance, 100)
        XCTAssertEqual(account.availableBalance, 100)
        XCTAssertTrue(try transactions().isEmpty)
    }

    func testErrorThrownInsideCommitAlsoRollsBack() throws {
        struct Boom: Error {}
        let account = try savedAccount(balance: 100)
        XCTAssertThrowsError(try Ledger.commit(context, touching: [account]) {
            Ledger.apply(-10, to: account)
            throw Boom()
        })
        XCTAssertEqual(account.balance, 100)
    }

    func testSaveOrReportSetsAMessageOnFailure() throws {
        _ = try savedAccount(balance: 1)
        var message: String?
        let binding = Binding(get: { message }, set: { message = $0 })
        Ledger.debugFailNextCommit = true
        XCTAssertFalse(Ledger.saveOrReport(context, error: binding))
        XCTAssertNotNil(message)
        XCTAssertTrue(Ledger.saveOrReport(context, error: binding))
    }

    func testExpenseTrackerRollsBackAFailedExpense() throws {
        let account = try savedAccount(balance: 1_000)
        let transactionViewModel = TransactionViewModel(modelContext: context, loadImmediately: false)
        let accountViewModel = AccountViewModel(modelContext: context, transactionViewModel: transactionViewModel)
        let tracker = ExpenseTrackerViewModel(
            modelContext: context,
            accountViewModel: accountViewModel,
            transactionViewModel: transactionViewModel
        )

        Ledger.debugFailNextCommit = true
        tracker.addExpense(
            account: account, amount: 250, merchant: "Sample Store", description: "Sample",
            categoryName: "Shopping", date: Date(), source: .manualEntry, isIncome: false
        )
        guard case .transactionFailed? = tracker.error else {
            return XCTFail("expected .transactionFailed, got \(String(describing: tracker.error))")
        }
        XCTAssertEqual(account.balance, 1_000)
        XCTAssertEqual(account.availableBalance, 1_000)
        XCTAssertTrue(try transactions().isEmpty)
    }

    // MARK: Fixed deposits

    private func deposit(from account: Account, maturingOn date: Date) throws -> FixedDeposit {
        let deposit = FixedDeposit(
            userId: "test-user", nickname: "Sample FD", principal: 10_000, interestRate: 7,
            tenureMonths: 12, maturityDate: date, maturityValue: 10_700, sourceAccountId: account.id
        )
        context.insert(deposit)
        try context.save()
        return deposit
    }

    func testMaturedDepositIsCreditedOnce() throws {
        let account = try savedAccount(balance: 500)
        let fd = try deposit(from: account, maturingOn: Date().addingTimeInterval(-86_400))

        DepositService.processMatured(in: context)
        DepositService.processMatured(in: context)

        XCTAssertEqual(fd.status, .matured)
        XCTAssertEqual(account.balance, 11_200)
        XCTAssertEqual(try transactions().count, 1)
    }

    func testDepositNotYetDueIsLeftAlone() throws {
        let account = try savedAccount(balance: 500)
        let fd = try deposit(from: account, maturingOn: Date().addingTimeInterval(30 * 86_400))
        DepositService.processMatured(in: context)
        XCTAssertEqual(fd.status, .active)
        XCTAssertEqual(account.balance, 500)
    }

    func testFailedMaturityCreditCanBeRetried() throws {
        let account = try savedAccount(balance: 500)
        let fd = try deposit(from: account, maturingOn: Date().addingTimeInterval(-86_400))

        Ledger.debugFailNextCommit = true
        DepositService.processMatured(in: context)
        XCTAssertEqual(fd.status, .active)
        XCTAssertEqual(account.balance, 500)
        XCTAssertTrue(try transactions().isEmpty)

        DepositService.processMatured(in: context)
        XCTAssertEqual(fd.status, .matured)
        XCTAssertEqual(account.balance, 11_200)
    }

    func testBreakingADepositReturnsPrincipalOnce() throws {
        let account = try savedAccount(balance: 500)
        let fd = try deposit(from: account, maturingOn: Date().addingTimeInterval(30 * 86_400))

        XCTAssertTrue(DepositService.breakDeposit(fd, in: context))
        XCTAssertEqual(fd.status, .closed)
        XCTAssertEqual(account.balance, 10_500)
        XCTAssertFalse(DepositService.breakDeposit(fd, in: context))
        XCTAssertEqual(account.balance, 10_500)
    }

    func testDepositsDoNothingWithoutASession() throws {
        AuthenticationService.sessionIsLive = false
        let account = try savedAccount(balance: 500)
        let fd = try deposit(from: account, maturingOn: Date().addingTimeInterval(-86_400))
        DepositService.processMatured(in: context)
        XCTAssertFalse(DepositService.breakDeposit(fd, in: context))
        XCTAssertEqual(fd.status, .active)
        XCTAssertEqual(account.balance, 500)
    }
}
