import XCTest
@testable import Banking_Application

final class CardModelTests: XCTestCase {

    func testLastFourFromFullPAN() {
        XCTAssertEqual(Card.lastFourDigits(from: "4111111111111111"), "1111")
        XCTAssertEqual(Card.lastFourDigits(from: "1234"), "1234")
        XCTAssertEqual(Card.lastFourDigits(from: "12 34 56"), "3456")
    }

    func testInitStoresOnlyLastFour() {
        let card = Card(
            userId: "u1",
            cardNumber: "4111111111119876",
            cardType: .visa,
            expirationMonth: 1,
            expirationYear: 2030,
            cardHolderName: "TEST USER",
            dailyLimit: 1000,
            monthlyLimit: 5000
        )
        XCTAssertEqual(card.cardNumber, "9876")
        XCTAssertEqual(card.maskedCardNumber, "•••• •••• •••• 9876")
    }

    func testDailyLimitProgressClamps() {
        let card = Card(
            userId: "u1",
            cardNumber: "0000",
            cardType: .visa,
            expirationMonth: 1,
            expirationYear: 2030,
            cardHolderName: "TEST",
            dailyLimit: 1000,
            monthlyLimit: 5000,
            dailySpent: 300,
            monthlySpent: 6000
        )
        XCTAssertEqual(card.dailyLimitProgress, 0.3, accuracy: 0.001)
        XCTAssertEqual(card.monthlyLimitProgress, 1.0, accuracy: 0.001)
    }

    func testZeroLimitProgressIsZero() {
        let card = Card(
            userId: "u1",
            cardNumber: "0000",
            cardType: .visa,
            expirationMonth: 1,
            expirationYear: 2030,
            cardHolderName: "TEST",
            dailyLimit: 0,
            monthlyLimit: 0,
            dailySpent: 50,
            monthlySpent: 50
        )
        XCTAssertEqual(card.dailyLimitProgress, 0)
        XCTAssertEqual(card.monthlyLimitProgress, 0)
    }
}
