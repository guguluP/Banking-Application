import Foundation

/// Looks up Indian bank branch details (IFSC codes) via Razorpay's free,
/// public, CORS-enabled IFSC API — no API key required, and RBI-sourced
/// data. https://github.com/razorpay/ifsc/wiki/API
///
/// This is the app's first real network call. Deliberately narrow and
/// self-contained rather than folded into a general-purpose networking
/// layer, since nothing else in the app talks to the network yet — IFSC
/// lookup is genuinely independent of the backend API and shouldn't wait
/// on that wiring to exist.
enum IFSCLookupService {
    struct BranchDetails: Decodable {
        let bank: String
        let ifsc: String
        let branch: String
        let address: String?
        let city: String?
        let district: String?
        let state: String?
        let contact: String?
        let neft: Bool?
        let rtgs: Bool?
        let imps: Bool?
        let upi: Bool?

        enum CodingKeys: String, CodingKey {
            case bank = "BANK"
            case ifsc = "IFSC"
            case branch = "BRANCH"
            case address = "ADDRESS"
            case city = "CITY"
            case district = "DISTRICT"
            case state = "STATE"
            case contact = "CONTACT"
            case neft = "NEFT"
            case rtgs = "RTGS"
            case imps = "IMPS"
            case upi = "UPI"
        }

        /// "HDFC BANK, BANGALORE" style summary for a compact display line.
        var summary: String {
            if let city, !city.isEmpty {
                return "\(bank), \(city)"
            }
            return bank
        }
    }

    enum LookupError: LocalizedError {
        case invalidFormat
        case notFound
        case network(Error)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "That doesn't look like a valid IFSC code. It should be 11 characters, like PUNB0123456."
            case .notFound:
                return "No branch found for that IFSC code. Double-check it and try again."
            case .network:
                return "Couldn't reach the bank directory right now. You can still save this payee and verify the code later."
            }
        }
    }

    /// IFSC format: 4 letters (bank code) + 0 (reserved) + 6 alphanumeric
    /// (branch code). This check is free and instant, so it always runs
    /// before any network call.
    static func isValidFormat(_ code: String) -> Bool {
        let pattern = "^[A-Z]{4}0[A-Z0-9]{6}$"
        return code.range(of: pattern, options: .regularExpression) != nil
    }

    static func lookup(_ code: String) async throws -> BranchDetails {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard isValidFormat(normalized) else {
            throw LookupError.invalidFormat
        }

        guard let url = URL(string: "https://ifsc.razorpay.com/\(normalized)") else {
            throw LookupError.invalidFormat
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw LookupError.network(URLError(.badServerResponse))
            }
            guard http.statusCode != 404 else {
                throw LookupError.notFound
            }
            guard (200...299).contains(http.statusCode) else {
                throw LookupError.network(URLError(.badServerResponse))
            }
            return try JSONDecoder().decode(BranchDetails.self, from: data)
        } catch let error as LookupError {
            throw error
        } catch {
            throw LookupError.network(error)
        }
    }
}
