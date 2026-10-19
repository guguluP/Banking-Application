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
        context.processPendingChanges()
        XCTAssertEqual(checking.balance, 1000)
        XCTAssertEqual(checking.availableBalance, 1000)
        XCTAssertEqual(savings.balance, 0)
        let leftover = (checking.transactions ?? []).filter { !$0.isDeleted }
        XCTAssertTrue(leftover.isEmpty)
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

    func testPublicPrivateAndPaymentsBanks() {
        let samples: [(String, String, String)] = [
            ("SBI: Rs.500.00 debited from A/c XX8891. UPI/store@oksbi/UTR 998877665544", "State Bank of India", "8891"),
            ("INR 1,250.50 credited to your Canara Bank a/c XX4412. NEFT Ref No CANA12345678", "Canara Bank", "4412"),
            ("Kotak Bank: INR 75.00 spent on card XX2200 at SWIGGY. Ref 556677889900", "Kotak Mahindra Bank", "2200"),
            ("Paytm Payments Bank: Rs 20 debited from a/c XX1001 towards recharge. UPI Ref No 112233445566", "Paytm Payments Bank", "1001"),
            ("Odisha Gramin Bank: Rs.300.00 debited from A/c XX7788. UTR 445566778899", "Regional Rural Bank", "7788")
        ]
        for (text, bank, last4) in samples {
            let event = BankSMSParser.parse(text)
            XCTAssertEqual(event?.bank, bank, text)
            XCTAssertEqual(event?.accountLast4, last4, text)
        }
    }

    func testOTPMessageIsDropped() {
        XCTAssertNil(BankSMSParser.parse("Your OTP is 482193. Do not share it with anyone."))
    }

    func testUnpunctuatedAmountStaysWhole() {
        let event = BankSMSParser.parse("INR 10000 debited from HDFC Bank A/c **0400. UTR 123456789012")
        XCTAssertEqual(event?.amount, 10000)
        XCTAssertEqual(event?.direction, .debit)
    }

    func testDebitThatMentionsCreditedToStaysDebit() {
        let text = "INR 10000 debited from HDFC Bank A/c **0400 and credited to merchant@okhdfc. UTR 123456789012"
        let event = BankSMSParser.parse(text)
        XCTAssertEqual(event?.amount, 10000)
        XCTAssertEqual(event?.direction, .debit)
    }

    func testDebitAlertWithDistantOTPWarningStillParses() {
        let text = "Rs.250.00 debited from HDFC Bank A/c **0400 on 02-10-26 towards SWIGGY BANGALORE for dinner. UTR 123456789012. Never share OTP with anyone."
        let event = BankSMSParser.parse(text)
        XCTAssertEqual(event?.amount, Decimal(string: "250.00"))
        XCTAssertEqual(event?.direction, .debit)
        XCTAssertEqual(event?.accountLast4, "0400")
    }

    func testRoundUpWithNoOtherSavingsDebitsOnlyThePayment() throws {
        let context = container.mainContext
        let checking = Account(userId: "u", accountNumber: "100200300400", accountType: .checking, balance: 1000, availableBalance: 1000)
        context.insert(checking)
        AppSettings.shared.isRoundUpEnabled = true
        defer { AppSettings.shared.isRoundUpEnabled = false }
        _ = try TransactionService.post(
            from: checking,
            amount: Decimal(string: "12.50")!,
            rail: .transfer,
            counterparty: "200300400500",
            description: "Out",
            category: "Transfer",
            recipientAccountNumber: "200300400500",
            applyRoundUp: true,
            in: context
        )
        XCTAssertEqual(checking.balance, Decimal(string: "987.50"))
        XCTAssertEqual(checking.availableBalance, Decimal(string: "987.50"))
    }

    func testClosedDestinationDoesNotLeaveADebit() {
        let context = container.mainContext
        let checking = Account(userId: "u", accountNumber: "100200300400", accountType: .checking, balance: 1000, availableBalance: 1000)
        let closed = Account(userId: "u", accountNumber: "100200300499", accountType: .savings, accountStatus: .closed, balance: 20, availableBalance: 20)
        context.insert(checking)
        context.insert(closed)
        XCTAssertThrowsError(try TransactionService.post(
            from: checking,
            amount: 40,
            rail: .transfer,
            counterparty: closed.accountNumber,
            description: "Move",
            category: "Transfer",
            recipientAccountNumber: closed.accountNumber,
            in: context
        )) { error in
            XCTAssertEqual(error as? PaymentFailure, .destinationNotMovable)
        }
        XCTAssertEqual(checking.balance, 1000)
        XCTAssertEqual(checking.availableBalance, 1000)
        XCTAssertEqual(closed.balance, 20)
        XCTAssertTrue((checking.transactions ?? []).isEmpty)
    }

    func testHoldSurvivesATransfer() throws {
        let context = container.mainContext
        let checking = Account(userId: "u", accountNumber: "100200300400", accountType: .checking, balance: 1000, availableBalance: Decimal(string: "849.50")!)
        checking.reservedHold = Decimal(string: "150.50")!
        context.insert(checking)
        _ = try TransactionService.post(
            from: checking,
            amount: 100,
            rail: .transfer,
            counterparty: "200300400500",
            description: "Out",
            category: "Transfer",
            recipientAccountNumber: "200300400500",
            in: context
        )
        XCTAssertEqual(checking.balance, 900)
        XCTAssertEqual(checking.availableBalance, Decimal(string: "749.50"))
    }

    func testBillPayDoesNotNeedBillerAccountField() throws {
        let context = container.mainContext
        let checking = Account(userId: "u", accountNumber: "100200300400", accountType: .checking, balance: 100, availableBalance: 100)
        let biller = Biller(userId: "u", name: "Electricity", accountNumber: "99887766")
        context.insert(checking)
        context.insert(biller)
        let viewModel = BillPayViewModel()
        viewModel.amount = "25"
        viewModel.billerAccount = ""
        XCTAssertTrue(viewModel.payBill(biller: biller, from: checking, in: context))
        XCTAssertEqual(checking.balance, Decimal(string: "75.25"))
    }

    func testLockoutIgnoresWallClockJump() {
        let keychain = MemoryLockoutStore()
        let uptime: TimeInterval = 1_000
        keychain.set("1030", forKey: KeychainKey.lockoutUptimeDeadline)
        keychain.set("500000", forKey: KeychainKey.lockoutBootAnchor)
        keychain.set("30", forKey: KeychainKey.lockoutDuration)
        let remaining = AuthenticationService.remainingLockout(keychain: keychain, nowUptime: uptime, nowWall: 501_000)
        XCTAssertEqual(remaining, 30)
        let jumped = AuthenticationService.remainingLockout(keychain: keychain, nowUptime: uptime, nowWall: 9_000_000)
        XCTAssertEqual(jumped, 30)
    }

    func testSpendAccountMatchUsesBankAndLast4() {
        let hdfc = Account(userId: "u", accountNumber: "4521", accountType: .checking, balance: 0, availableBalance: 0)
        hdfc.bankName = "HDFC Bank"
        let icici = Account(userId: "u", accountNumber: "4521", accountType: .checking, balance: 0, availableBalance: 0)
        icici.bankName = "ICICI Bank"
        let sbi = Account(userId: "u", accountNumber: "8891", accountType: .savings, balance: 0, availableBalance: 0)
        sbi.bankName = "SBI"

        let accounts = [hdfc, icici, sbi]
        XCTAssertEqual(Account.match(last4: "4521", bank: "HDFC Bank", among: accounts)?.bankName, "HDFC Bank")
        XCTAssertEqual(Account.match(last4: "4521", bank: "HDFC", among: accounts)?.bankName, "HDFC Bank")
        XCTAssertNil(Account.match(last4: "4521", bank: "Axis Bank", among: accounts))
        XCTAssertEqual(Account.match(last4: "8891", bank: "Unknown", among: accounts)?.bankName, "SBI")
        XCTAssertNil(Account.match(last4: "4521", bank: "Unknown", among: accounts))
        XCTAssertNil(Account.match(last4: "9999", bank: "HDFC Bank", among: accounts))
        XCTAssertEqual(Account.canonicalBank("SBI"), "State Bank of India")
        XCTAssertEqual(sbi.expenseAccountLabel, "SBI · 8891")
    }

    func testCompanyPayeesAndPersonPayees() {
        XCTAssertEqual(MerchantDirectory.company(in: "blinkit.payu@axisbank")?.displayName, "Blinkit")
        XCTAssertEqual(MerchantDirectory.company(in: "blinkit.payu@axisbank")?.categoryName, "Groceries")
        XCTAssertEqual(MerchantDirectory.company(in: "towards ZOMATO BANGALORE")?.displayName, "Zomato")
        XCTAssertEqual(MerchantDirectory.company(in: "UBER INDIA")?.displayName, "Uber")
        XCTAssertEqual(MerchantDirectory.company(in: "UBER INDIA")?.categoryName, "Transport")
        XCTAssertEqual(MerchantDirectory.company(in: "SWIGGY INSTAMART")?.displayName, "Swiggy Instamart")
        XCTAssertEqual(MerchantDirectory.company(in: "SWIGGY INSTAMART")?.categoryName, "Groceries")
        XCTAssertNil(MerchantDirectory.company(in: "rahul@oksbi"))
        XCTAssertTrue(MerchantDirectory.isPersonPayee("rahul@oksbi"))
        XCTAssertTrue(MerchantDirectory.isPersonPayee("9876543210@ybl"))
        XCTAssertTrue(MerchantDirectory.isPersonPayee("RAHUL SHARMA"))
        XCTAssertFalse(MerchantDirectory.isPersonPayee("UBER INDIA"))
        XCTAssertEqual(MerchantDirectory.personName(from: "rahul@oksbi"), "Rahul")

        let classifier = CategoryKeywordClassifier()
        XCTAssertEqual(classifier.classify(text: "vegetables 80").categoryName, "Groceries")
        XCTAssertEqual(classifier.classify(text: "sabzi 40").categoryName, "Groceries")
        XCTAssertEqual(classifier.classify(text: "auto 120").categoryName, "Transport")
    }

    func testDirectRiderStaysUberOnlyForThatPayee() throws {
        let context = container.mainContext
        let hdfc = Account(userId: "u", accountNumber: "4521", accountType: .checking, balance: 0, availableBalance: 0)
        hdfc.bankName = "HDFC Bank"
        let icici = Account(userId: "u", accountNumber: "4521", accountType: .checking, balance: 0, availableBalance: 0)
        icici.bankName = "ICICI Bank"
        context.insert(hdfc)
        context.insert(icici)

        let blinkit = BankImportPipeline.ingestSMS(
            "Rs.180.00 debited from HDFC Bank A/c **4521 to blinkit.payu@axisbank. UTR 123456789012",
            in: context
        )
        XCTAssertEqual(blinkit?.merchant, "Blinkit")
        XCTAssertEqual(blinkit?.categoryName, "Groceries")
        XCTAssertEqual(blinkit?.status, .posted)
        let blinkitTx = try context.fetch(FetchDescriptor<Transaction>()).first { $0.merchant == "Blinkit" }
        XCTAssertEqual(blinkitTx?.account?.bankName, "HDFC Bank")
        XCTAssertNotEqual(blinkitTx?.account?.id, icici.id)

        let rahul = BankImportPipeline.ingestSMS(
            "Rs.220.00 debited from HDFC Bank A/c **4521 to rahul@oksbi. UTR 223456789012",
            in: context
        )
        XCTAssertEqual(rahul?.needsPayeeChoice, true)
        XCTAssertEqual(rahul?.status, .pendingReview)
        XCTAssertEqual(rahul?.personName, "Rahul")
        XCTAssertTrue(try context.fetch(FetchDescriptor<Transaction>()).filter { $0.merchant?.contains("Uber") == true }.isEmpty)

        XCTAssertNotNil(rahul)
        XCTAssertTrue(BankImportPipeline.remember(rahul!, as: .uber, in: context))
        let ride = try context.fetch(FetchDescriptor<Transaction>()).first { $0.merchant == "Uber · Rahul" }
        XCTAssertEqual(ride?.category, "Transport")
        XCTAssertEqual(ride?.account?.bankName, "HDFC Bank")

        let again = BankImportPipeline.ingestSMS(
            "Rs.240.00 debited from HDFC Bank A/c **4521 to rahul@oksbi. UTR 323456789012",
            in: context
        )
        XCTAssertEqual(again?.needsPayeeChoice, false)
        XCTAssertEqual(again?.merchant, "Uber · Rahul")
        XCTAssertEqual(again?.status, .posted)

        let vendor = BankImportPipeline.ingestSMS(
            "Rs.90.00 debited from HDFC Bank A/c **4521 to ramesh@ybl. UTR 423456789012",
            in: context
        )
        XCTAssertEqual(vendor?.needsPayeeChoice, true)
        XCTAssertNotEqual(vendor?.merchant, "Uber · Rahul")
        XCTAssertNotNil(vendor)
        XCTAssertTrue(BankImportPipeline.remember(vendor!, as: .groceries, in: context))
        let vegetables = try context.fetch(FetchDescriptor<Transaction>()).first { $0.amount == 90 }
        XCTAssertEqual(vegetables?.category, "Groceries")
        XCTAssertEqual(vegetables?.merchant?.contains("Uber"), false)
    }
}
