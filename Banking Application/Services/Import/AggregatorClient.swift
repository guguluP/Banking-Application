import Foundation

struct NormalizedFIEvent: Codable {
    var amount: String
    var direction: String
    var accountLast4: String
    var merchant: String
    var externalRef: String
    var bank: String
}

/// Sandbox Account Aggregator client. Production AA needs a regulated entity
/// and a technology provider (Setu, Finvu, Anumati). This client talks only to
/// a backend you run yourself; the sample server deletes FI payloads after fetch.
@MainActor
enum AggregatorClient {
    static var baseURL = URL(string: "http://127.0.0.1:8787")!

    static func createConsent(mobile: String) async throws -> String {
        struct Body: Codable { var mobile: String }
        struct Reply: Codable { var consentId: String }
        let reply: Reply = try await post(path: "v1/consent", body: Body(mobile: mobile))
        return reply.consentId
    }

    static func fetchEvents(consentId: String) async throws -> [RawBankEvent] {
        let rows: [NormalizedFIEvent] = try await get(path: "v1/fi/\(consentId)")
        return rows.compactMap { row in
            guard let amount = Decimal(string: row.amount) else { return nil }
            return RawBankEvent(
                amount: amount,
                direction: row.direction == "credit" ? .credit : .debit,
                accountLast4: row.accountLast4,
                merchant: row.merchant,
                externalRef: row.externalRef,
                occurredAt: Date(),
                bank: row.bank,
                source: .aggregator,
                confidence: 0.9
            )
        }
    }

    private static func post<Body: Encodable, Reply: Decodable>(path: String, body: Body) async throws -> Reply {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await decode(request)
    }

    private static func get<Reply: Decodable>(path: String) async throws -> Reply {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        return try await decode(request)
    }

    private static func decode<Reply: Decodable>(_ request: URLRequest) async throws -> Reply {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Reply.self, from: data)
    }
}
