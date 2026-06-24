import Foundation
import AppIntents
import SwiftUI

struct PayBillerIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Pay Biller"
    nonisolated static let description = "Make a payment to a saved biller"
    
    @Parameter(title: "Biller")
    var biller: String
    
    @Parameter(title: "Amount")
    var amount: Double
    
    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Pay \(\.$amount) to \(\.$biller)")
    }
    
    func perform() async throws -> some IntentResult {
        return .result(value: "Payment initiated")
    }
}

struct TransferMoneyIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Transfer Money"
    nonisolated static let description = "Transfer money to another account"
    
    @Parameter(title: "From Account")
    var fromAccount: String
    
    @Parameter(title: "To Account")
    var toAccount: String
    
    @Parameter(title: "Amount")
    var amount: Double
    
    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Transfer \(\.$amount) from \(\.$fromAccount) to \(\.$toAccount)")
    }
    
    func perform() async throws -> some IntentResult {
        return .result(value: "Transfer initiated")
    }
}

struct BillerEntity: AppEntity, TypeDisplayRepresentable {
    nonisolated static let typeDisplayName: LocalizedStringResource = "Biller"
    nonisolated static let typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Biller")
    nonisolated static let typeName = "biller"
    
    let id: String
    let displayName: String
    let accountNumber: String
    
    nonisolated var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: "Biller"),
            subtitle: LocalizedStringResource(stringLiteral: displayName)
        )
    }
    
    static let defaultQuery = BillerQuery()
}

struct BillerQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BillerEntity] {
        return []
    }
    
    func suggestedEntities() async throws -> [BillerEntity] {
        return []
    }
    
    func entities(matching string: String) async throws -> [BillerEntity] {
        return []
    }
}

struct AccountEntity: AppEntity, TypeDisplayRepresentable {
    nonisolated static let typeDisplayName: LocalizedStringResource = "Account"
    nonisolated static let typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Account")
    nonisolated static let typeName = "account"
    
    let id: String
    let displayName: String
    let accountNumber: String
    let balance: Decimal
    
    nonisolated var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: displayName),
            subtitle: LocalizedStringResource(stringLiteral: "Account")
        )
    }
    
    static let defaultQuery = AccountQuery()
}

struct AccountQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AccountEntity] {
        return []
    }
    
    func suggestedEntities() async throws -> [AccountEntity] {
        return []
    }
    
    func entities(matching string: String) async throws -> [AccountEntity] {
        return []
    }
}
