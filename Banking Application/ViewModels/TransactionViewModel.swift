import Foundation
import Combine

@MainActor
class TransactionViewModel: ObservableObject {
    @Published private(set) var transactions: [Transaction] = []
    @Published var isLoading: Bool = false
    @Published var error: AppError?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadTransactions(for: "acc_001")
    }
    
    func loadTransactions(for accountId: String) {
        isLoading = true
        NetworkingService.shared.getTransactions(accountId: accountId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = AppError.networkError
                }
            } receiveValue: { [weak self] transactions in
                self?.transactions = transactions
            }
            .store(in: &cancellables)
    }
    
    func getTransactions(for accountId: String) -> [Transaction] {
        return transactions.filter { $0.accountId == accountId }
    }
    
    var recentTransactions: [Transaction] {
        transactions.sorted { $0.transactionDate > $1.transactionDate }
    }
    
    func getTotalDeposits() -> Decimal {
        return transactions.filter { $0.isCredit }.reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    func getTotalWithdrawals() -> Decimal {
        return transactions.filter { !$0.isCredit }.reduce(Decimal(0)) { $0 + $1.amount }
    }
    
    func clearError() {
        error = nil
    }
}