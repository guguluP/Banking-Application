import XCTest
import SwiftData
@testable import Banking_Application

@MainActor
final class PaymentServiceTests: XCTestCase {
    private var container: ModelContainer!

    override func setUp() async throws {
        let configuration = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: PersistenceController.schema, configurations: [configuration])
        AuthenticationService.sessionIsLive = true
        AuthenticationService.movementBlocked = false
    }

    override func tearDown() async throws {
        TransactionService.debugFailNextSave = false
        AuthenticationService.sessionIsLive = false
    }

    func testInternalTransferCreditsDestination() throws {
        let context = container.mainContext
        let checking = Account(userId: "u", accountNumber: "100200300400", accountType: .checking, balance: 1000, availableBalance: 1000)
        let savings = Account(userId: "u", accountNumber: "100200300401", accountType: .savings, balance: 50, availableBalance: 50)
        context.insert(checking)
        context.insert(savings)
        _ = try TransactionService.post(
            from: checking,
            amount: 100,
            rail: .transfer,
            counterparty: savings.accountNumber,
            description: "Move",
            category: "Transfer",
            recipientAccountNumber: savings.accountNumber,
            in: context
        )
        XCTAssertEqual(checking.availableBalance, 900)
        XCTAssertEqual(savings.availableBalance, 150)
        XCTAssertEqual(savings.transactions?.contains { $0.isCredit && $0.amount == 100 }, true)
    }

    func testFrozenAccountCannotSend() {
        let context = container.mainContext
        let checking = Account(userId: "u", accountNumber: "100200300400", accountType: .checking, accountStatus: .frozen, balance: 1000, availableBalance: 1000)
        context.insert(checking)
        XCTAssertThrowsError(try TransactionService.post(
            from: checking,
            amount: 10,
            rail: .upi,
            counterparty: "shop@upi",
            description: "UPI",
            category: "UPI",
            in: context
        )) { error in
            XCTAssertEqual(error as? PaymentFailure, .accountNotMovable)
        }
        XCTAssertEqual(checking.availableBalance, 1000)
    }

    func testFailedSaveRollsBackRoundUp() {
        let context = container.mainContext
        let checking = Account(userId: "u", accountNumber: "100200300400", accountType: .checking, balance: 1000, availableBalance: 1000)
        let savings = Account(userId: "u", accountNumber: "100200300401", accountType: .savings, balance: 0, availableBalance: 0)
        context.insert(checking)
        context.insert(savings)
        AppSettings.shared.isRoundUpEnabled = true
        TransactionService.debugFailNextSave = true
        XCTAssertThrowsError(try TransactionService.post(
            from: checking,
            amount: Decimal(string: "12.50")!,
            rail: .transfer,
            counterparty: "200300400500",
            description: "Out",
            category: "Transfer",
            recipientAccountNumber: "200300400500",
            applyRoundUp: true,
            in: context
        ))
        XCTAssertEqual(checking.balance, 1000)
        XCTAssertEqual(checking.availableBalance, 1000)
        XCTAssertEqual(savings.balance, 0)
        XCTAssertEqual(checking.transactions?.isEmpty ?? true, true)
        AppSettings.shared.isRoundUpEnabled = false
    }

    func testRoundUpUsesDecimals() {
        XCTAssertEqual(TransactionService.roundUpSpare(for: Decimal(string: "12.50")!), Decimal(string: "7.50"))
        XCTAssertEqual(TransactionService.roundUpSpare(for: 20), 0)
    }

    func testHDFCParserExtractsUTR() {
        let text = "Rs.250.00 debited from A/c **0400 on 02-10-26 to merchant@okhdfc UTR 123456789012"
        let event = BankSMSParser.parse(text)
        XCTAssertEqual(event?.amount, Decimal(string: "250.00"))
        XCTAssertEqual(event?.accountLast4, "0400")
        XCTAssertEqual(event?.externalRef, "123456789012")
        XCTAssertEqual(event?.direction, .debit)
    }

    func testOTPMessageIsDropped() {
        XCTAssertNil(BankSMSParser.parse("Your OTP is 482193. Do not share it with anyone."))
    }

    func testLockoutIgnoresWallClockJump() {
        let keychain = KeychainService.shared
        let uptime: TimeInterval = 1_000
        keychain.set("1030", forKey: KeychainKey.lockoutUptimeDeadline)
        keychain.set("500000", forKey: KeychainKey.lockoutBootAnchor)
        keychain.set("30", forKey: KeychainKey.lockoutDuration)
        let remaining = AuthenticationService.remainingLockout(keychain: keychain, nowUptime: uptime, nowWall: 501_000)
        XCTAssertEqual(remaining, 30)
        let jumped = AuthenticationService.remainingLockout(keychain: keychain, nowUptime: uptime, nowWall: 9_000_000)
        XCTAssertEqual(jumped, 30)
        keychain.delete(forKey: KeychainKey.lockoutUptimeDeadline)
        keychain.delete(forKey: KeychainKey.lockoutBootAnchor)
        keychain.delete(forKey: KeychainKey.lockoutDuration)
    }
}
