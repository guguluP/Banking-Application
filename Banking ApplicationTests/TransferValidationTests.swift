import XCTest
@testable import Banking_Application

@MainActor
final class TransferValidationTests: XCTestCase {

    func testRecipientRequiresEightToTwelveDigits() {
        let vm = TransferViewModel()
        vm.recipientAccount = "123"
        XCTAssertFalse(vm.isRecipientValid)
        vm.recipientAccount = "12345678"
        XCTAssertTrue(vm.isRecipientValid)
        vm.recipientAccount = "123456789012"
        XCTAssertTrue(vm.isRecipientValid)
        vm.recipientAccount = "1234567890123"
        XCTAssertFalse(vm.isRecipientValid)
        vm.recipientAccount = "12AB5678"
        XCTAssertFalse(vm.isRecipientValid)
    }

    func testAmountMustBePositiveAndWithinCap() {
        let vm = TransferViewModel()
        vm.amount = "0"
        XCTAssertFalse(vm.isAmountValid)
        vm.amount = "-5"
        XCTAssertFalse(vm.isAmountValid)
        vm.amount = "100.50"
        XCTAssertTrue(vm.isAmountValid)
        vm.amount = "10001"
        XCTAssertFalse(vm.isAmountValid)
        vm.amount = "abc"
        XCTAssertFalse(vm.isAmountValid)
    }

    func testFormValidRequiresBothFields() {
        let vm = TransferViewModel()
        XCTAssertFalse(vm.isFormValid)
        vm.recipientAccount = "100200300400"
        vm.amount = "50"
        XCTAssertTrue(vm.isFormValid)
    }
}
