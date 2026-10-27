import XCTest
import SwiftData
@testable import Banking_Application

/// Made-up sample messages only. Account digits and references are not real.
@MainActor
final class ImportPipelineTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try makeInMemoryContainer()
        AuthenticationService.movementBlocked = false
    }

    override func tearDown() async throws {
        Ledger.debugFailNextCommit = false
    }

    private func transactions() throws -> [Transaction] {
        try context.fetch(FetchDescriptor<Transaction>())
    }

    func testSameExternalRefIsADuplicate() throws {
        context.insert(makeDeclaredAccount())
        try context.save()

        let first = BankImportPipeline.ingestSMS(
            "Rs.120.00 debited from HDFC Bank A/c **4521 to blinkit.payu@axisbank. UTR 900000000001",
            in: context
        )
        let second = BankImportPipeline.ingestSMS(
            "Rs.135.00 debited from HDFC Bank A/c **4521 to blinkit.payu@axisbank. UTR 900000000001",
            in: context
        )
        XCTAssertEqual(first?.status, .posted)
        XCTAssertEqual(second?.status, .duplicate)
        XCTAssertEqual(try transactions().count, 1)
    }

    func testSameRawHashWithoutRefIsADuplicate() throws {
        context.insert(makeDeclaredAccount())
        try context.save()
        let event = RawBankEvent(
            amount: 42,
            direction: .debit,
            accountLast4: "4521",
            merchant: "Sample Cafe",
            externalRef: nil,
            occurredAt: Date(),
            bank: "HDFC Bank",
            source: .smsImport,
            confidence: 0.95
        )
        let first = BankImportPipeline.ingest(event, in: context)
        let second = BankImportPipeline.ingest(event, in: context)
        XCTAssertNotEqual(first?.status, .duplicate)
        XCTAssertEqual(second?.status, .duplicate)
        XCTAssertEqual(first?.rawHash, BankImportPipeline.rawHash(for: event))
        XCTAssertEqual(first?.rawHash, second?.rawHash)
    }

    func testRawHashUsesReceiptHashFormat() {
        let event = RawBankEvent(
            amount: 10, direction: .credit, accountLast4: "0001", merchant: nil, externalRef: "REF1",
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000), bank: "Sample Bank", source: .smsImport, confidence: 1
        )
        let hash = BankImportPipeline.rawHash(for: event)
        XCTAssertEqual(hash.count, 64)
        XCTAssertTrue(hash.allSatisfy { "0123456789abcdef".contains($0) })
        XCTAssertEqual(hash, BankImportPipeline.rawHash(for: event))
    }

    private func credit(ref: String) -> RawBankEvent {
        RawBankEvent(
            amount: 500, direction: .credit, accountLast4: "4521", merchant: "blinkit.payu@axisbank",
            externalRef: ref, occurredAt: Date(), bank: "HDFC Bank", source: .smsImport, confidence: 0.95
        )
    }

    func testCreditPostsWhenTheSaveSucceeds() throws {
        let account = makeDeclaredAccount(balance: 1_000)
        context.insert(account)
        try context.save()

        let row = BankImportPipeline.ingest(credit(ref: "900000000020"), in: context)
        XCTAssertEqual(row?.status, .posted)
        XCTAssertEqual(try transactions().count, 1)
        XCTAssertEqual(try transactions().first?.type, .deposit)
        XCTAssertEqual(account.balance, 1_000, "imports label spend; they do not move the balance")
    }

    func testFailedSaveRollsBackTheCredit() throws {
        let account = makeDeclaredAccount(balance: 1_000)
        context.insert(account)
        try context.save()

        Ledger.debugFailNextCommit = true
        let row = BankImportPipeline.ingest(credit(ref: "900000000021"), in: context)
        XCTAssertNotNil(row)
        XCTAssertEqual(row?.status, .pendingReview)
        XCTAssertTrue(try transactions().isEmpty)
        XCTAssertEqual(account.balance, 1_000)
        XCTAssertEqual(account.availableBalance, 1_000)

        // The review row is still there and the same message is not lost as a duplicate.
        try context.save()
        let stored = try context.fetch(FetchDescriptor<ImportedEvent>())
        XCTAssertEqual(stored.map(\.status), [.pendingReview])
    }

    func testBatchDedupesInsideTheBatchAndSavesOnce() throws {
        context.insert(makeDeclaredAccount())
        try context.save()

        let rows = BankImportPipeline.ingestBatch([
            "Rs.60.00 debited from HDFC Bank A/c **4521 to blinkit.payu@axisbank. UTR 900000000003",
            "Rs.60.00 debited from HDFC Bank A/c **4521 to blinkit.payu@axisbank. UTR 900000000003",
            "Rs.75.00 debited from HDFC Bank A/c **4521 to blinkit.payu@axisbank. UTR 900000000004",
            "Your OTP is 123456. Do not share it."
        ], in: context)

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.map(\.status), [.posted, .duplicate, .posted])
        XCTAssertFalse(context.hasChanges, "the batch should end with one save")
        XCTAssertEqual(try transactions().count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ImportedEvent>()).count, 3)
    }

    func testPurgeDropsOnlyOldDuplicateAndRejectedRows() throws {
        let now = Date()
        let old = Calendar.current.date(byAdding: .day, value: -(BankImportPipeline.staleRowRetentionDays + 5), to: now)!
        func row(_ status: ImportEventStatus, at date: Date, ref: String) -> ImportedEvent {
            let event = RawBankEvent(
                amount: 1, direction: .debit, accountLast4: "0001", merchant: "M", externalRef: ref,
                occurredAt: date, bank: "Sample Bank", source: .smsImport, confidence: 1
            )
            let row = ImportedEvent(event: event, hash: ref, categoryName: "Uncategorized")
            row.status = status
            context.insert(row)
            return row
        }
        _ = row(.duplicate, at: old, ref: "old-dup")
        _ = row(.rejected, at: old, ref: "old-rej")
        _ = row(.pendingReview, at: old, ref: "old-pending")
        _ = row(.posted, at: old, ref: "old-posted")
        _ = row(.duplicate, at: now, ref: "new-dup")
        try context.save()

        BankImportPipeline.purgeStaleRows(in: context, now: now)
        try context.save()

        let remaining = Set(try context.fetch(FetchDescriptor<ImportedEvent>()).compactMap(\.externalRef))
        XCTAssertEqual(remaining, ["old-pending", "old-posted", "new-dup"])
    }
}
