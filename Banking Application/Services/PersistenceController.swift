import Foundation
import Combine
import SwiftData

/// Single source of truth for the app's on-device + iCloud-synced data store.
///
/// This replaces the previous `NetworkingService` HTTP client and the standalone
/// Spring Boot backend for day-to-day app data: account balances, transactions,
/// cards, beneficiaries, and billers now live in SwiftData and are transparently
/// synced across the signed-in user's own devices through CloudKit's **private**
/// database (never a public/shared database), so no data is ever exposed to
/// other iCloud users. This also removes the app's dependence on a
/// self-hosted server, an HTTP stack, and manual Codable networking code —
/// everything is native Swift + Apple frameworks.
@MainActor
enum PersistenceController {

    /// The full schema synced with CloudKit. Every type here is a `@Model` class
    /// with default values and no unique constraints, which is required for
    /// CloudKit-backed SwiftData containers.
    static var schema: Schema {
        Schema([
            User.self,
            Account.self,
            Transaction.self,
            Card.self,
            Beneficiary.self,
            Biller.self,
            UPITransaction.self,
            FixedDeposit.self,
            Loan.self
        ])
    }

    /// The shared container. CloudKit sync is enabled automatically; SwiftData
    /// mirrors local writes to the user's private CloudKit database in the
    /// background and merges remote changes back in, so the same account looks
    /// identical across the user's iPhone, iPad, and Mac.
    static let shared: ModelContainer = {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            seedIfNeeded(container: container)
            sanitizeStoredCards(container: container)
            return container
        } catch {
            // Falling back to an in-memory store keeps the app usable (e.g. in
            // Simulator without an iCloud account) instead of crashing outright.
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            guard let fallback = try? ModelContainer(for: schema, configurations: [fallbackConfiguration]) else {
                fatalError("Unable to create ModelContainer: \(error)")
            }
            seedIfNeeded(container: fallback)
            sanitizeStoredCards(container: fallback)
            return fallback
        }
    }()

    /// A separate, always-in-memory container used by SwiftUI previews and tests.
    static var preview: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        seedIfNeeded(container: container, force: true)
        return container
    }()

    /// Seeds a first-run demo account so the app is usable immediately after
    /// install, without requiring a backend. Real account/card provisioning in a
    /// production build would instead come from the issuing bank's enrollment
    /// flow — this stands in for that.
    private static func seedIfNeeded(container: ModelContainer, force: Bool = false) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Account>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard force || existingCount == 0 else { return }

        let userId = "user_001"

        let checking = Account(
            userId: userId,
            accountNumber: "100200300400",
            accountType: .checking,
            balance: 4250.75,
            availableBalance: 4100.25,
            nickname: "Everyday Checking",
            isPrimary: true
        )
        let savings = Account(
            userId: userId,
            accountNumber: "100200300401",
            accountType: .savings,
            balance: 12800.00,
            availableBalance: 12800.00,
            nickname: "Rainy Day Savings",
            interestRate: 3.25
        )

        context.insert(checking)
        context.insert(savings)

        let calendar = Calendar.current
        let sampleTransactions: [(Decimal, TransactionType, String, String?, Int)] = [
            (54.32, .payment, "Grocery Mart", "Groceries", 0),
            (12.99, .payment, "Coffee Roasters", "Dining", 1),
            (1200.00, .deposit, "Payroll Deposit", "Income", 2),
            (89.10, .payment, "Fuel Station", "Fuel", 3),
            (32.40, .payment, "Streaming Service", "Dining", 5),
            (15.10, .interest, "Savings Interest", "Interest", 6)
        ]

        for (amount, type, desc, category, daysAgo) in sampleTransactions {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let txn = Transaction(
                accountId: checking.id,
                type: type,
                amount: amount,
                description: desc,
                transactionDate: date,
                category: category
            )
            txn.account = checking
            context.insert(txn)
        }

        // Store last four only — never a full PAN, even in demo seed data.
        let card = Card(
            userId: userId,
            cardNumber: "1111",
            cardType: .visa,
            expirationMonth: 12,
            expirationYear: calendar.component(.year, from: Date()) + 2,
            cardHolderName: "JOHN DOE",
            dailyLimit: 1000,
            monthlyLimit: 5000,
            dailySpent: 320,
            monthlySpent: 1850
        )
        context.insert(card)

        let billers: [(String, String, String)] = [
            ("Electric Company", "123456789", "Electric Bill"),
            ("Water Services", "987654321", "Water Bill"),
            ("Internet Provider", "555555555", "Internet Bill")
        ]
        for (name, account, nickname) in billers {
            context.insert(Biller(userId: userId, name: name, accountNumber: account, nickname: nickname))
        }

        let fdStartDate = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        let fdTenureMonths = 12
        let fdRate = FDRateCard.rate(forMonths: fdTenureMonths)
        let fdMaturityDate = calendar.date(byAdding: .month, value: fdTenureMonths, to: fdStartDate) ?? Date()
        let fdPrincipal: Decimal = 50000
        let fd = FixedDeposit(
            userId: userId,
            nickname: "1-Year Deposit",
            principal: fdPrincipal,
            interestRate: fdRate,
            tenureMonths: fdTenureMonths,
            startDate: fdStartDate,
            maturityDate: fdMaturityDate,
            maturityValue: FDRateCard.maturityValue(principal: fdPrincipal, annualRatePercent: fdRate, months: fdTenureMonths),
            sourceAccountId: savings.id
        )
        context.insert(fd)

        try? context.save()
    }

    /// Migrates any legacy rows that still hold a full PAN down to last-four only.
    private static func sanitizeStoredCards(container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Card>()
        guard let cards = try? context.fetch(descriptor) else { return }
        var changed = false
        for card in cards {
            let normalized = Card.lastFourDigits(from: card.cardNumber)
            if card.cardNumber != normalized {
                card.cardNumber = normalized
                changed = true
            }
        }
        if changed {
            try? context.save()
        }
    }
}
