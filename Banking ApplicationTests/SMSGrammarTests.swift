import XCTest
@testable import Banking_Application

/// Generic, made-up bank alerts. None of these are real messages.
@MainActor
final class SMSGrammarTests: XCTestCase {
    func testGenericDebitAlert() {
        let sms = IndianBankSMSGrammar.parse("Rs.1,234.50 debited from HDFC Bank A/c **7001 to sample.merchant@okicici. UTR 910000000001")
        XCTAssertEqual(sms?.amount, Decimal(string: "1234.50"))
        XCTAssertEqual(sms?.isCredit, false)
        XCTAssertEqual(sms?.accountLast4, "7001")
        XCTAssertEqual(sms?.externalRef, "910000000001")
        XCTAssertEqual(sms?.bank, "HDFC Bank")
    }

    func testGenericCreditAlert() {
        let sms = IndianBankSMSGrammar.parse("INR 2,000.00 credited to your Canara Bank a/c XX7002. UTR 910000000002")
        XCTAssertEqual(sms?.amount, 2000)
        XCTAssertEqual(sms?.isCredit, true)
        XCTAssertEqual(sms?.accountLast4, "7002")
    }

    func testIndianDigitGrouping() {
        let sms = IndianBankSMSGrammar.parse("INR 1,00,000.00 debited from HDFC Bank A/c **7003. UTR 910000000003")
        XCTAssertEqual(sms?.amount, 100_000)
    }

    func testUnknownBankStillParsesWithLowerConfidence() {
        let known = IndianBankSMSGrammar.parse("Rs.10.00 debited from HDFC Bank A/c **7004. UTR 910000000004")
        let unknown = IndianBankSMSGrammar.parse("Rs.10.00 debited from your account")
        XCTAssertNotNil(unknown)
        XCTAssertEqual(unknown?.bank, "Indian bank")
        XCTAssertLessThan(unknown?.confidence ?? 1, known?.confidence ?? 0)
    }

    func testMessageWithoutAmountOrDirectionIsIgnored() {
        XCTAssertNil(IndianBankSMSGrammar.parse("Your statement for this month is ready."))
        XCTAssertNil(IndianBankSMSGrammar.parse("   "))
    }

    func testOTPMessagesAreRejected() {
        let samples = [
            "Your OTP is 482193. Do not share it with anyone.",
            "123456 is your one time password for a payment of Rs.500.00 at Sample Store.",
            "Use OTP 9921 to approve Rs.250.00 debited from A/c **7005."
        ]
        for text in samples {
            XCTAssertTrue(IndianBankSMSGrammar.looksLikeOTP(text), text)
            XCTAssertNil(IndianBankSMSGrammar.parse(text), text)
            XCTAssertNil(BankSMSParser.parse(text), text)
        }
    }

    func testDistantOTPWarningDoesNotRejectADebit() {
        let text = "Rs.80.00 debited from HDFC Bank A/c **7006 to sample.shop@okaxis. UTR 910000000006. Never share your OTP with anyone."
        XCTAssertFalse(IndianBankSMSGrammar.looksLikeOTP(text))
        XCTAssertEqual(IndianBankSMSGrammar.parse(text)?.amount, 80)
    }

    func testSkippingTheOTPCheckIsOnlyForCallersThatRanIt() {
        let text = "Use OTP 9921 to approve Rs.250.00 debited from A/c **7005."
        XCTAssertNil(IndianBankSMSGrammar.parse(text))
        XCTAssertNotNil(IndianBankSMSGrammar.parse(text, checkOTP: false))
    }
}
