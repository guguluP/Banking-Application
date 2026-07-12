import XCTest
@testable import Banking_Application

/// Run via Xcode: Product → Test (add this file to the unit test target if needed).
final class CryptoServiceTests: XCTestCase {

    func testHashIsDeterministicForSamePasscodeAndSalt() {
        let salt = "fixed-salt-for-test"
        let a = CryptoService.hash(passcode: "1234", salt: salt)
        let b = CryptoService.hash(passcode: "1234", salt: salt)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 64) // SHA-256 hex
    }

    func testDifferentSaltsProduceDifferentHashes() {
        let a = CryptoService.hash(passcode: "1234", salt: "salt-a")
        let b = CryptoService.hash(passcode: "1234", salt: "salt-b")
        XCTAssertNotEqual(a, b)
    }

    func testDifferentPasscodesProduceDifferentHashes() {
        let salt = CryptoService.generateSalt()
        let a = CryptoService.hash(passcode: "1234", salt: salt)
        let b = CryptoService.hash(passcode: "4321", salt: salt)
        XCTAssertNotEqual(a, b)
    }

    func testConstantTimeEqualsMatchesEqualStrings() {
        XCTAssertTrue(CryptoService.constantTimeEquals("abcd", "abcd"))
        XCTAssertFalse(CryptoService.constantTimeEquals("abcd", "abce"))
        XCTAssertFalse(CryptoService.constantTimeEquals("abc", "abcd"))
    }

    func testGenerateSaltIsNonEmptyAndVaries() {
        let a = CryptoService.generateSalt()
        let b = CryptoService.generateSalt()
        XCTAssertFalse(a.isEmpty)
        XCTAssertNotEqual(a, b)
    }
}
