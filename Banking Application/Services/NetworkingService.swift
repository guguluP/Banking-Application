import Foundation
import Combine

enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed
    case invalidResponse
    case decodingError
    case serverError(Int)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .requestFailed: return "Request failed"
        case .invalidResponse: return "Invalid response"
        case .decodingError: return "Failed to decode response"
        case .serverError(let code): return "Server error: \(code)"
        case .unknown: return "Unknown error"
        }
    }
}

class NetworkingService {
    static let shared = NetworkingService()
    
    private let baseURL = "http://localhost:8080/api"
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    func request<T: Decodable>(_ endpoint: String, method: String = "GET", parameters: [String: Any]? = nil, headers: [String: String]? = nil) -> AnyPublisher<T, NetworkError> {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return Fail<T, NetworkError>(error: .invalidURL)
                .eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        
        headers?.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let parameters = parameters {
            if method == "GET" {
                var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
                urlComponents?.queryItems = parameters.map { (key, value) in URLQueryItem(name: key, value: String(describing: value)) }
                urlRequest.url = urlComponents?.url
            } else {
                do {
                    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                } catch {
                    return Fail<T, NetworkError>(error: .requestFailed)
                        .eraseToAnyPublisher()
                }
            }
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return session.dataTaskPublisher(for: urlRequest)
            .tryMap { output -> Data in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    return output.data
                } else {
                    throw NetworkError.serverError(httpResponse.statusCode)
                }
            }
            .decode(type: T.self, decoder: decoder)
            .mapError { error in
                if let networkError = error as? NetworkError {
                    return networkError
                } else {
                    if error is URLError {
                        return .requestFailed
                    } else {
                        return .decodingError
                    }
                }
            }
            .eraseToAnyPublisher()
    }
    
    func getAccounts(userId: String) -> AnyPublisher<[Account], NetworkError> {
        return request("accounts/\(userId)")
    }
    
    func getAccount(id: String) -> AnyPublisher<Account, NetworkError> {
        return request("accounts/\(id)")
    }
    
    func getTransactions(accountId: String) -> AnyPublisher<[Transaction], NetworkError> {
        return request("transactions/\(accountId)")
    }
    
    func transferFunds(fromAccountId: String, toAccountId: String, amount: Decimal, description: String) -> AnyPublisher<Transaction, NetworkError> {
        let parameters: [String: Any] = [
            "fromAccountId": fromAccountId,
            "toAccountId": toAccountId,
            "amount": NSDecimalNumber(decimal: amount).stringValue,
            "description": description
        ]
        return request("transfers", method: "POST", parameters: parameters)
    }
    
    func payBill(billerId: String, amount: Decimal, fromAccountId: String, date: Date) -> AnyPublisher<Transaction, NetworkError> {
        let dateFormatter = ISO8601DateFormatter()
        let parameters: [String: Any] = [
            "billerId": billerId,
            "amount": NSDecimalNumber(decimal: amount).stringValue,
            "fromAccountId": fromAccountId,
            "date": dateFormatter.string(from: date)
        ]
        return request("bill-payments", method: "POST", parameters: parameters)
    }
    
    func depositCheck(imageData: Data, accountId: String, amount: Decimal) -> AnyPublisher<Transaction, NetworkError> {
        let base64Image = imageData.base64EncodedString()
        let parameters: [String: Any] = [
            "accountId": accountId,
            "amount": NSDecimalNumber(decimal: amount).stringValue,
            "imageData": base64Image
        ]
        return request("check-deposits", method: "POST", parameters: parameters)
    }
}