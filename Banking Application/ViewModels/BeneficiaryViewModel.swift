import Foundation
import Combine
import SwiftData

@MainActor
class BeneficiaryViewModel: ObservableObject {
    init(
        nickname: String = "",
        accountNumber: String = "",
        confirmAccountNumber: String = "",
        ifscCode: String = "",
        resolvedBranch: IFSCLookupService.BranchDetails? = nil,
        isLookingUp: Bool = false,
        lookupError: String? = nil,
        error: AppError? = nil
    ) {
        self.nickname = nickname
        self.accountNumber = accountNumber
        self.confirmAccountNumber = confirmAccountNumber
        self.ifscCode = ifscCode
        self.resolvedBranch = resolvedBranch
        self.isLookingUp = isLookingUp
        self.lookupError = lookupError
        self.error = error
    }
    
    @Published var nickname = ""
    @Published var accountNumber = ""
    @Published var confirmAccountNumber = ""
    @Published var ifscCode = ""
    @Published var resolvedBranch: IFSCLookupService.BranchDetails?
    @Published var isLookingUp = false
    @Published var lookupError: String?
    @Published var error: AppError?

    // MARK: - Validation

    var isNicknameValid: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isAccountNumberValid: Bool {
        let cleaned = accountNumber.trimmingCharacters(in: .whitespaces)
        return cleaned.count >= 8 && cleaned.count <= 18 && cleaned.allSatisfy(\.isNumber)
    }

    var accountNumbersMatch: Bool {
        !confirmAccountNumber.isEmpty && accountNumber == confirmAccountNumber
    }

    var isIFSCFormatValid: Bool {
        IFSCLookupService.isValidFormat(ifscCode.trimmingCharacters(in: .whitespaces).uppercased())
    }

    var canSave: Bool {
        isNicknameValid && isAccountNumberValid && accountNumbersMatch && isIFSCFormatValid
    }

    // MARK: - IFSC lookup

    /// Verifies the branch exists before letting the user save a payee
    /// against it. Network failure doesn't block saving — format validation
    /// alone is enough to proceed — but a confirmed *invalid* code does.
    func lookupIFSC() async {
        let code = ifscCode.trimmingCharacters(in: .whitespaces).uppercased()
        guard IFSCLookupService.isValidFormat(code) else {
            resolvedBranch = nil
            lookupError = nil
            return
        }

        isLookingUp = true
        lookupError = nil
        defer { isLookingUp = false }

        do {
            resolvedBranch = try await IFSCLookupService.lookup(code)
        } catch let error as IFSCLookupService.LookupError {
            resolvedBranch = nil
            lookupError = error.errorDescription
        } catch {
            resolvedBranch = nil
            lookupError = "Couldn't reach the bank directory right now."
        }
    }

    // MARK: - Persistence

    func saveBeneficiary(userId: String, in context: ModelContext) -> Bool {
        guard canSave else {
            error = .invalidInput
            return false
        }

        let bankName = resolvedBranch?.bank ?? "Bank"
        let beneficiary = Beneficiary(
            userId: userId,
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            accountNumber: accountNumber.trimmingCharacters(in: .whitespaces),
            bankName: bankName,
            bankCode: ifscCode.trimmingCharacters(in: .whitespaces).uppercased(),
            accountType: .checking
        )

        context.insert(beneficiary)

        do {
            try context.save()
            reset()
            return true
        } catch {
            self.error = .unknownError("Couldn't save this payee. Please try again.")
            return false
        }
    }

    func delete(_ beneficiary: Beneficiary, in context: ModelContext) {
        context.delete(beneficiary)
        try? context.save()
    }

    func toggleFavorite(_ beneficiary: Beneficiary, in context: ModelContext) {
        beneficiary.isFavorite.toggle()
        try? context.save()
    }

    private func reset() {
        nickname = ""
        accountNumber = ""
        confirmAccountNumber = ""
        ifscCode = ""
        resolvedBranch = nil
        lookupError = nil
    }
}

