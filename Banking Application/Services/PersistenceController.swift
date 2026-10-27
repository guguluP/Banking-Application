import Foundation
import SwiftData

/// Single source of truth for the app's on-device data store.
///
/// This replaces the previous `NetworkingService` HTTP client and the standalone
/// Spring Boot backend for day-to-day app data: account balances, transactions,
/// cards, beneficiaries, and billers live in SwiftData on this device only.
/// The store is created with `cloudKitDatabase: .none`, so nothing is synced to
/// iCloud. The models keep CloudKit-compatible shapes (defaults, no unique
/// constraints) so sync could be turned on later without a migration.
@MainActor
enum PersistenceController {

    /// The full schema. Every type here is a `@Model` class with default values
    /// and no unique constraints, which keeps it CloudKit-compatible even though
    /// sync is currently off.
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
            Loan.self,
            ExpenseCategory.self,
            Budget.self,
            ScheduledInstruction.self,
            SavingsGoal.self,
            Envelope.self,
            MoneyRequest.self,
            TransactionDispute.self,
            DeviceSession.self,
            SecurityEvent.self,
            ImportedEvent.self,
            RememberedPayee.self,
            AAConsent.self,
            VaultDocument.self,
            VirtualCard.self,
            NetWorthSnapshot.self
        ])
    }

    /// The shared on-disk container. CloudKit sync is off (`cloudKitDatabase: .none`),
    /// so data stays on this device and is not mirrored to iCloud.
    static var didFallBackToMemory = false
    static var storeFailureDescription: String?

    static let shared: ModelContainer = {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            protectStore(at: configuration.url)
            prepare(container)
            return container
        } catch {
            didFallBackToMemory = true
            storeFailureDescription = error.localizedDescription
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            guard let fallback = try? ModelContainer(for: schema, configurations: [fallbackConfiguration]) else {
                fatalError("Unable to create ModelContainer: \(error)")
            }
            prepare(fallback)
            return fallback
        }
    }()

    private static func prepare(_ container: ModelContainer) {
        seedIfNeeded(container: container)
        seedDefaultCategoriesIfNeeded(container: container)
        sanitizeStoredCards(container: container)
        TransactionService.adoptLedgerBaselines(in: container.mainContext)
    }

    private static func protectStore(at url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }

    /// A separate, always-in-memory container used by SwiftUI previews and tests.
    static var preview: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        seedIfNeeded(container: container, force: true)
        seedDefaultCategoriesIfNeeded(container: container)
        return container
    }()

    /// Seeds billers and a demo card. Bank accounts are not created here:
    /// after login the user names each account by bank and last four digits.
    private static func seedIfNeeded(container: ModelContainer, force: Bool = false) {
        let context = container.mainContext
        let billerCount = (try? context.fetchCount(FetchDescriptor<Biller>())) ?? 0
        guard force || billerCount == 0 else { return }

        let userId = LocalUser.id
        let calendar = Calendar.current

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

        Ledger.saveOrLog(context, "seed data")
    }

    /// Seeds the built-in expense categories on first run. Idempotent and
    /// additive: if the user already has categories (including if they've
    /// deleted/hidden some built-ins), this is a no-op, so it's safe to call
    /// on every launch.
    private static func seedDefaultCategoriesIfNeeded(container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<ExpenseCategory>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for (index, seed) in ExpenseCategory.defaultSeedSet.enumerated() {
            let category = ExpenseCategory(
                name: seed.name,
                systemImage: seed.systemImage,
                colorHex: seed.colorHex,
                isBuiltIn: true,
                sortOrder: index
            )
            context.insert(category)
        }

        Ledger.saveOrLog(context, "seed data")
    }

    /// Migrates any legacy rows that still hold a full PAN down to last-four only.
    /// Runs at most once per install after a successful scan.
    private static func sanitizeStoredCards(container: ModelContainer) {
        let flagKey = "persistence.didSanitizeCardPANs"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

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
            Ledger.saveOrLog(context, "seed data")
        }
        UserDefaults.standard.set(true, forKey: flagKey)
    }
}
