import XCTest
import SwiftData
@testable import Banking_Application

/// In-memory store shared by the newer test files. Same configuration as `PaymentServiceTests`.
@MainActor
func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: PersistenceController.schema, configurations: [configuration])
}

/// A declared spend account (bank name set), which is what SMS imports file against.
@MainActor
func makeDeclaredAccount(bank: String = "HDFC Bank", last4: String = "4521", balance: Decimal = 0) -> Account {
    let account = Account(userId: "test-user", accountNumber: last4, accountType: .checking, balance: balance, availableBalance: balance)
    account.bankName = bank
    return account
}
