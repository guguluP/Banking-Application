import XCTest
@testable import Banking_Application

final class CurrencyFormatterTests: XCTestCase {

    func testFormatsINRWithTwoFractionDigits() {
        let text = CurrencyFormatter.shared.string(from: Decimal(string: "1234.5")!)
        // Locale may vary (₹1,234.50 vs INR 1,234.50) — assert amount core.
        XCTAssertTrue(text.contains("1,234.50") || text.contains("1234.50") || text.contains("1.234,50"))
    }

    func testZeroFormats() {
        let text = CurrencyFormatter.shared.string(from: 0)
        XCTAssertFalse(text.isEmpty)
    }
}
