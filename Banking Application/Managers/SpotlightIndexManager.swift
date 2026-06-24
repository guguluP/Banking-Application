import Foundation
import CoreSpotlight
import MobileCoreServices

@MainActor
struct SpotlightIndexManager {
    static let shared = SpotlightIndexManager()
    
    private init() {}
    
    func indexBiller(_ biller: Biller) {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.data.identifier)
        attributeSet.title = biller.displayName
        attributeSet.identifier = biller.id
        attributeSet.keywords = [biller.name, biller.accountNumber, "biller", "payment"]
        attributeSet.contentDescription = "Biller Account: \(biller.accountNumber)"
        
        let item = CSSearchableItem(uniqueIdentifier: "biller_\(biller.id)", domainIdentifier: "com.banksecure.billers", attributeSet: attributeSet)
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("Failed to index biller: \(error)")
            }
        }
    }
    
    func indexAccount(_ account: Account) {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.data.identifier)
        attributeSet.title = account.nickname ?? account.accountType.rawValue
        attributeSet.identifier = account.id
        attributeSet.keywords = [account.accountNumber, account.accountType.rawValue, "account", "balance"]
        attributeSet.contentDescription = "Balance: \(account.formattedBalance)"
        
        let item = CSSearchableItem(uniqueIdentifier: "account_\(account.id)", domainIdentifier: "com.banksecure.accounts", attributeSet: attributeSet)
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("Failed to index account: \(error)")
            }
        }
    }
    
    func indexTransaction(_ transaction: Transaction) {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.data.identifier)
        attributeSet.title = transaction.description
        attributeSet.identifier = transaction.id
        attributeSet.keywords = [transaction.type.rawValue, transaction.category ?? "", "transaction"]
        attributeSet.contentDescription = "Amount: \(transaction.formattedAmount)"
        
        let item = CSSearchableItem(uniqueIdentifier: "transaction_\(transaction.id)", domainIdentifier: "com.banksecure.transactions", attributeSet: attributeSet)
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("Failed to index transaction: \(error)")
            }
        }
    }
    
    func indexAllBillers(_ billers: [Biller]) {
        let items = billers.map { biller -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.data.identifier)
            attributeSet.title = biller.displayName
            attributeSet.identifier = biller.id
            attributeSet.keywords = [biller.name, biller.accountNumber, "biller", "payment"]
            attributeSet.contentDescription = "Biller Account: \(biller.accountNumber)"
            return CSSearchableItem(uniqueIdentifier: "biller_\(biller.id)", domainIdentifier: "com.banksecure.billers", attributeSet: attributeSet)
        }
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                print("Failed to index billers: \(error)")
            }
        }
    }
    
    func indexAllAccounts(_ accounts: [Account]) {
        let items = accounts.map { account -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.data.identifier)
            attributeSet.title = account.nickname ?? account.accountType.rawValue
            attributeSet.identifier = account.id
            attributeSet.keywords = [account.accountNumber, account.accountType.rawValue, "account", "balance"]
            attributeSet.contentDescription = "Balance: \(account.formattedBalance)"
            return CSSearchableItem(uniqueIdentifier: "account_\(account.id)", domainIdentifier: "com.banksecure.accounts", attributeSet: attributeSet)
        }
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                print("Failed to index accounts: \(error)")
            }
        }
    }
    
    func deleteAllItems() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.banksecure.billers", "com.banksecure.accounts", "com.banksecure.transactions"]) { error in
            if let error = error {
                print("Failed to delete items: \(error)")
            }
        }
    }
}