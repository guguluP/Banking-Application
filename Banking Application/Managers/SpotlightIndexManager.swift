import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import os

private let spotlightLog = Logger(subsystem: "com.banksecure.app", category: "spotlight")

/// Indexes app content into system-wide Spotlight/Siri Suggestions so items can be found
/// and deep-linked to from outside the app.
///
/// IMPORTANT: Spotlight's index lives outside the app's passcode/biometric lock and can
/// surface in OS-level search and Siri Suggestions. Never put sensitive financial data
/// (account numbers, balances, transaction amounts) into `keywords` or `contentDescription`
/// here -- only non-sensitive, deep-linking-friendly identifiers (nicknames, names, types).
@MainActor
struct SpotlightIndexManager {
    static let shared = SpotlightIndexManager()

    private init() {}

    private func billerAttributeSet(for biller: Biller) -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.data.identifier)
        attributeSet.title = biller.displayName
        attributeSet.identifier = biller.id
        attributeSet.keywords = [biller.name, "biller", "payment"]
        attributeSet.contentDescription = "Biller"
        return attributeSet
    }

    private func accountAttributeSet(for account: Account) -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.data.identifier)
        attributeSet.title = account.nickname ?? account.accountType.rawValue
        attributeSet.identifier = account.id
        attributeSet.keywords = [account.accountType.rawValue, "account"]
        attributeSet.contentDescription = account.accountType.rawValue
        return attributeSet
    }

    func indexAllBillers(_ billers: [Biller]) {
        let items = billers.map { biller -> CSSearchableItem in
            CSSearchableItem(uniqueIdentifier: "biller_\(biller.id)", domainIdentifier: "com.banksecure.billers", attributeSet: billerAttributeSet(for: biller))
        }
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                spotlightLog.error("Failed to index billers: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func indexAllAccounts(_ accounts: [Account]) {
        let items = accounts.map { account -> CSSearchableItem in
            CSSearchableItem(uniqueIdentifier: "account_\(account.id)", domainIdentifier: "com.banksecure.accounts", attributeSet: accountAttributeSet(for: account))
        }
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                spotlightLog.error("Failed to index accounts: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func deleteAllItems() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.banksecure.billers", "com.banksecure.accounts", "com.banksecure.transactions"]) { error in
            if let error = error {
                spotlightLog.error("Failed to delete items: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
