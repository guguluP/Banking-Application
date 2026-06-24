# Banking Backend - Java Spring Boot

## Quick Start

### 1. Prerequisites
- Java 17+
- MySQL 8.0+
- Maven

### 2. Setup MySQL Database
```bash
# Create database
mysql -u root -p < src/main/resources/schema.sql

# Load seed data
mysql -u root -p banking_db < src/main/resources/data.sql
```

### 3. Configure Database
Edit `src/main/resources/application.properties`:
```properties
spring.datasource.url=jdbc:mysql://localhost:3306/banking_db
spring.datasource.username=your_username
spring.datasource.password=your_password
```

### 4. Run Application
```bash
./mvnw spring-boot:run
# API available at http://localhost:8080
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/accounts/{userId}` | GET | Get user accounts |
| `/api/accounts/{fromAccountId}/transfer` | POST | Transfer between accounts |
| `/api/upi/pay` | POST | UPI payment |
| `/api/upi/transactions/{accountId}` | GET | UPI transaction history |

## iOS Swift Integration

```swift
// BankingAPIService.swift
struct BankingAPI {
    static let baseURL = "http://localhost:8080/api"
    
    static func fetchAccounts() async throws -> [Account] {
        let url = URL(string: "\(baseURL)/accounts/user_001")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Account].self, from: data)
    }
    
    static func transfer(amount: Double, from: String, to: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/accounts/\(from)/transfer?toAccountId=\(to)&amount=\(amount)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode([String: Bool].self, from: data)
        return result["success"] ?? false
    }
}