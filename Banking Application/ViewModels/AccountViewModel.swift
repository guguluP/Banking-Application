import Foundation
import Combine
import SwiftUI

@MainActor
class AccountViewModel: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var upiTransactions: [UPITransaction] = []
    @Published var weeklySpending: [SpendingDataPoint] = []
    @Published var categoryBreakdown: [CategorySpending] = []
    @Published var isLoading: Bool = false
    @Published var error: AppError?
    
    private var cancellables = Set<AnyCancellable>()
    private let transactionViewModel: TransactionViewModel
    
    init(transactionViewModel: TransactionViewModel) {
        self.transactionViewModel = transactionViewModel
        loadAccounts()
    }
    
    var totalBalance: Decimal { accounts.filter { $0.accountType != .credit }.reduce(Decimal(0)) { $0 + $1.balance } }
    var totalAvailableBalance: Decimal { accounts.filter { $0.accountType != .credit }.reduce(Decimal(0)) { $0 + $1.availableBalance } }
    
    func loadAccounts() {
        loadAccounts(userId: "user_001")
    }
    
    func loadAccounts(userId: String) {
        isLoading = true
        NetworkingService.shared.getAccounts(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure = completion {
                    // Error handling can be wired to UI if needed
                }
            } receiveValue: { [weak self] accounts in
                self?.accounts = accounts
                self?.loadAnalytics()
            }
            .store(in: &cancellables)
    }
    
    func getAccount(id: String) -> Account? {
        return accounts.first { $0.id == id }
    }
    
    func addUPITransaction(upiId: String, amount: Decimal) {
        let txn = UPITransaction(
            id: "upi_\(UUID().uuidString)",
            upiId: upiId,
            amount: amount,
            date: Date()
        )
        upiTransactions.insert(txn, at: 0)
        loadAnalytics()
    }
    
    func loadAnalytics() {
        weeklySpending = calculateWeeklySpending()
        categoryBreakdown = calculateCategoryBreakdown()
    }
    
    func clearError() {
        error = nil
    }
    
    private func calculateWeeklySpending() -> [SpendingDataPoint] {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let recentTransactions = transactionViewModel.recentTransactions.filter { $0.transactionDate >= sevenDaysAgo && !$0.isCredit }
        
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: recentTransactions) { transaction in
            calendar.startOfDay(for: transaction.transactionDate)
        }
        
        var dataPoints: [SpendingDataPoint] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let dayStart = calendar.startOfDay(for: date)
                let dayString = dayStart.formatted(.dateTime.weekday(.abbreviated))
                let amount = grouped[dayStart]?.reduce(Decimal(0)) { $0 + $1.amount } ?? Decimal(0)
                dataPoints.append(SpendingDataPoint(day: dayString, amount: amount))
            }
        }
        
        return dataPoints.reversed()
    }
    
    private func calculateCategoryBreakdown() -> [CategorySpending] {
        let expenseTransactions = transactionViewModel.recentTransactions.filter { !$0.isCredit }
        
        let grouped = Dictionary(grouping: expenseTransactions) { $0.category ?? "Uncategorized" }
        
        let categoryColors: [String: Color] = [
            "Groceries": .green,
            "Dining": .orange,
            "Fuel": .red,
            "Income": .blue,
            "Interest": .purple,
            "Transfer": .yellow,
            "Payment": .pink
        ]
        
        var categorySpending: [CategorySpending] = []
        for (category, transactions) in grouped {
            let totalAmount = transactions.reduce(Decimal(0)) { $0 + $1.amount }
            let color = categoryColors[category] ?? .gray
            categorySpending.append(CategorySpending(name: category, amount: totalAmount, color: color))
        }
        
        return categorySpending.sorted { $0.amount > $1.amount }
    }
}