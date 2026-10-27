import XCTest
@testable import Banking_Application

@MainActor
final class AmountParserTests: XCTestCase {
    func testPlainNumbers() {
        XCTAssertEqual(AmountParser.parse("250"), 250)
        XCTAssertEqual(AmountParser.parse("12.50"), Decimal(string: "12.50"))
        XCTAssertEqual(AmountParser.parse("  99.99 \n"), Decimal(string: "99.99"))
    }

    func testGroupingCommas() {
        XCTAssertEqual(AmountParser.parse("1,250.50"), Decimal(string: "1250.50"))
        XCTAssertEqual(AmountParser.parse("1,00,000"), 100_000)
        XCTAssertEqual(AmountParser.parse("100,000"), 100_000)
    }

    func testCurrencyMarkers() {
        XCTAssertEqual(AmountParser.parse("₹500"), 500)
        XCTAssertEqual(AmountParser.parse("Rs. 1,200"), 1_200)
        XCTAssertEqual(AmountParser.parse("rs 75"), 75)
        XCTAssertEqual(AmountParser.parse("INR 40.25"), Decimal(string: "40.25"))
        XCTAssertEqual(AmountParser.parse("300 INR"), 300)
    }

    func testRejectsEmptyAndNonNumeric() {
        XCTAssertNil(AmountParser.parse(""))
        XCTAssertNil(AmountParser.parse("   "))
        XCTAssertNil(AmountParser.parse("₹"))
        XCTAssertNil(AmountParser.parse("abc"))
    }

    func testMatchesDecimalStringForInputThatAlreadyParsed() {
        for text in ["0", "0.5", "10", "1234.5678", "-20"] {
            XCTAssertEqual(AmountParser.parse(text), Decimal(string: text), text)
        }
    }
}
