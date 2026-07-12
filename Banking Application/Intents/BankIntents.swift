import Foundation
@preconcurrency import AppIntents
import SwiftUI
import SwiftData

enum BankIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case accountNotFound
    case billerNotFound
    case invalidAmount
    case insufficientFunds
    case saveFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .accountNotFound: return "That account couldn't be found."
        case .billerNotFound: return "That biller couldn't be found."
        case .invalidAmount: return "Enter an amount greater than zero."
        case .insufficientFunds: return "That account doesn't have enough available balance."
        case .saveFailed: return "The transaction couldn't be saved. Please try again in the app."
        }
    }
}

struct PayBillerIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Pay Biller"
    nonisolated static let description = IntentDescription("Make a payment to a saved biller")
    nonisolated static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "From Account")
    var fromAccount: AccountEntity

    @Parameter(title: "Biller")
    var biller: BillerEntity

    @Parameter(title: "Amount")
    var amount: Double

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Pay \(\.$amount) to \(\.$biller) from \(\.$fromAccount)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard amount > 0, let amountDecimal = Decimal(string: String(amount)) else {
            throw BankIntentError.invalidAmount
        }

        let context = PersistenceController.shared.mainContext
        let accountId = fromAccount.id
        let billerId = biller.id

        guard let account = try context.fetch(
            FetchDescriptor<Account>(predicate: #Predicate { $0.id == accountId })
        ).first else {
            throw BankIntentError.accountNotFound
        }

        guard let billerModel = try context.fetch(
            FetchDescriptor<Biller>(predicate: #Predicate { $0.id == billerId })
        ).first else {
            throw BankIntentError.billerNotFound
        }

        guard amountDecimal <= account.availableBalance else {
            throw BankIntentError.insufficientFunds
        }

        account.balance -= amountDecimal
        account.availableBalance -= amountDecimal

        let txn = Transaction(
            accountId: account.id,
            type: .payment,
            amount: amountDecimal,
            description: billerModel.displayName,
            counterparty: billerModel.name,
            transactionDate: Date(),
            category: "Payment",
            status: .completed
        )
        txn.account = account
        context.insert(txn)

        do {
            try context.save()
        } catch {
            account.balance += amountDecimal
            account.availableBalance += amountDecimal
            context.delete(txn)
            throw BankIntentError.saveFailed
        }

        let confirmation = "Paid \(CurrencyFormatter.shared.string(from: amountDecimal)) to \(billerModel.displayName)."
        return .result(value: confirmation)
    }
}

struct TransferMoneyIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Transfer Money"
    nonisolated static let description = IntentDescription("Transfer money to another account")
    nonisolated static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "From Account")
    var fromAccount: AccountEntity

    @Parameter(title: "To Account Number")
    var toAccount: String

    @Parameter(title: "Amount")
    var amount: Double

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Transfer \(\.$amount) from \(\.$fromAccount) to \(\.$toAccount)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard amount > 0, let amountDecimal = Decimal(string: String(amount)) else {
            throw BankIntentError.invalidAmount
        }

        let context = PersistenceController.shared.mainContext
        let accountId = fromAccount.id

        guard let account = try context.fetch(
            FetchDescriptor<Account>(predicate: #Predicate { $0.id == accountId })
        ).first else {
            throw BankIntentError.accountNotFound
        }

        guard amountDecimal <= account.availableBalance else {
            throw BankIntentError.insufficientFunds
        }

        let recipient = toAccount.trimmingCharacters(in: .whitespaces)

        account.balance -= amountDecimal
        account.availableBalance -= amountDecimal

        let txn = Transaction(
            accountId: account.id,
            type: .transfer,
            amount: amountDecimal,
            description: "Transfer to \(recipient.suffix(4))",
            counterparty: recipient,
            transactionDate: Date(),
            category: "Transfer",
            status: .completed
        )
        txn.account = account
        context.insert(txn)

        do {
            try context.save()
        } catch {
            account.balance += amountDecimal
            account.availableBalance += amountDecimal
            context.delete(txn)
            throw BankIntentError.saveFailed
        }

        let confirmation = "Transferred \(CurrencyFormatter.shared.string(from: amountDecimal)) to account ending in \(recipient.suffix(4))."
        return .result(value: confirmation)
    }
}

struct BillerEntity: AppEntity {
    nonisolated static let typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Biller")
    
    let id: String
    let displayName: String
    let accountNumber: String
    
    nonisolated var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: displayName),
            subtitle: LocalizedStringResource(stringLiteral: accountNumber)
        )
    }
    
    static let defaultQuery = BillerQuery()
}

struct BillerQuery: EntityQuery {
    @MainActor
    private func allBillers() throws -> [Biller] {
        try PersistenceController.shared.mainContext.fetch(FetchDescriptor<Biller>())
    }

    @MainActor
    func entities(for identifiers: [String]) async throws -> [BillerEntity] {
        try allBillers()
            .filter { identifiers.contains($0.id) }
            .map { BillerEntity(id: $0.id, displayName: $0.displayName, accountNumber: $0.accountNumber) }
    }

    @MainActor
    func suggestedEntities() async throws -> [BillerEntity] {
        try allBillers().map { BillerEntity(id: $0.id, displayName: $0.displayName, accountNumber: $0.accountNumber) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [BillerEntity] {
        try allBillers()
            .filter { $0.displayName.localizedCaseInsensitiveContains(string) }
            .map { BillerEntity(id: $0.id, displayName: $0.displayName, accountNumber: $0.accountNumber) }
    }
}

struct AccountEntity: AppEntity {
    nonisolated static let typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Account")
    
    let id: String
    let displayName: String
    let accountNumber: String
    let balance: Decimal
    
    nonisolated var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: displayName),
            subtitle: LocalizedStringResource(stringLiteral: "•••• \(accountNumber.suffix(4))")
        )
    }
    
    static let defaultQuery = AccountQuery()
}

struct AccountQuery: EntityQuery {
    @MainActor
    private func allAccounts() throws -> [Account] {
        try PersistenceController.shared.mainContext.fetch(FetchDescriptor<Account>())
    }

    @MainActor
    private func toEntity(_ account: Account) -> AccountEntity {
        AccountEntity(
            id: account.id,
            displayName: account.nickname ?? account.accountType.rawValue,
            accountNumber: account.accountNumber,
            balance: account.balance
        )
    }

    @MainActor
    func entities(for identifiers: [String]) async throws -> [AccountEntity] {
        try allAccounts().filter { identifiers.contains($0.id) }.map(toEntity)
    }

    @MainActor
    func suggestedEntities() async throws -> [AccountEntity] {
        try allAccounts().map(toEntity)
    }

    @MainActor
    func entities(matching string: String) async throws -> [AccountEntity] {
        try allAccounts()
            .filter { ($0.nickname ?? $0.accountType.rawValue).localizedCaseInsensitiveContains(string) }
            .map(toEntity)
    }
}

struct CheckBalanceIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Check Balance"
    nonisolated static let description = IntentDescription("Check the available balance on an account")
    nonisolated static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "Account")
    var account: AccountEntity?

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Check balance for \(\.$account)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let context = PersistenceController.shared.mainContext

        if let account {
            let accountId = account.id
            guard let match = try context.fetch(
                FetchDescriptor<Account>(predicate: #Predicate { $0.id == accountId })
            ).first else {
                throw BankIntentError.accountNotFound
            }
            let name = match.nickname ?? match.accountType.rawValue
            let balance = CurrencyFormatter.shared.string(from: match.availableBalance)
            return .result(value: "Your \(name) balance is \(balance).")
        } else {
            let accounts = try context.fetch(FetchDescriptor<Account>())
            let total = accounts
                .filter { $0.accountType != .credit }
                .reduce(Decimal(0)) { $0 + $1.availableBalance }
            let formatted = CurrencyFormatter.shared.string(from: total)
            return .result(value: "Your total available balance is \(formatted).")
        }
    }
}

/// The single source of truth for what Siri, Spotlight, and the Shortcuts
/// app can actually discover and say by name. Defining an AppIntent alone
/// does not make it voice-invocable — without an entry here, Siri has no
/// phrase to match it to, no matter how complete the intent itself is.
@MainActor
struct BankAppShortcuts: @preconcurrency AppShortcutsProvider {
    static let appShortcuts: [AppShortcut] = [
        AppShortcut(
            intent: CheckBalanceIntent(),
            phrases: [
                "Check my balance in \(.applicationName)",
                "What's my balance in \(.applicationName)",
                "How much money do I have in \(.applicationName)"
            ],
            shortTitle: "Check Balance",
            systemImageName: "indianrupeesign.circle"
        ),
        AppShortcut(
            intent: PayBillerIntent(),
            phrases: [
                "Pay a bill with \(.applicationName)",
                "Pay biller using \(.applicationName)"
            ],
            shortTitle: "Pay Biller",
            systemImageName: "doc.text.fill"
        ),
        AppShortcut(
            intent: TransferMoneyIntent(),
            phrases: [
                "Transfer money with \(.applicationName)",
                "Send money using \(.applicationName)"
            ],
            shortTitle: "Transfer Money",
            systemImageName: "paperplane.fill"
        ),
        AppShortcut(
            intent: SummarizeTextIntent(),
            phrases: [
                "Summarize with \(.applicationName)",
                "Summarize text in \(.applicationName)",
                "Make a summary with \(.applicationName)"
            ],
            shortTitle: "Summarize Text",
            systemImageName: "sparkles"
        )
    ]
}
