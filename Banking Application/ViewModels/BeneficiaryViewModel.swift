import Foundation
import SwiftData

@MainActor
@Observable
final class BeneficiaryViewModel {
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
    
    var nickname = ""
    var accountNumber = ""
    var confirmAccountNumber = ""
    var ifscCode = ""
    var upiId = ""
    var resolvedBranch: IFSCLookupService.BranchDetails?
    var isLookingUp = false
    var lookupError: String?
    var error: AppError?
    /// Whether this payee should be marked favorite on save. Previously
    /// `Beneficiary.isFavorite` existed on the model with a working
    /// `toggleFavorite` method but no UI ever set it — this is the first
    /// real entry point for it.
    var isFavorite = false

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

    var isUPIValid: Bool {
        upiId.trimmingCharacters(in: .whitespacesAndNewlines).contains("@")
    }

    private var hasAccountNumber: Bool {
        !accountNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canSave: Bool {
        guard isNicknameValid else { return false }
        if hasAccountNumber {
            guard isAccountNumberValid && accountNumbersMatch && isIFSCFormatValid else { return false }
        }
        if isUPIValid { return true }
        return hasAccountNumber
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

        let trimmedAccount = accountNumber.trimmingCharacters(in: .whitespaces)
        let trimmedUPI = upiId.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = ifscCode.trimmingCharacters(in: .whitespaces).uppercased()
        let bankName = resolvedBranch?.bank ?? (trimmedAccount.isEmpty ? "UPI" : "Bank")
        let beneficiary = Beneficiary(
            userId: userId,
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            accountNumber: trimmedAccount,
            bankName: bankName,
            bankCode: code.isEmpty ? nil : code,
            accountType: .checking,
            isFavorite: isFavorite,
            upiId: trimmedUPI
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
        do {
            try Ledger.save(context, rollbackOnFailure: true)
        } catch {
            self.error = .unknownError("Couldn't delete this payee. Please try again.")
        }
    }

    func toggleFavorite(_ beneficiary: Beneficiary, in context: ModelContext) {
        beneficiary.isFavorite.toggle()
        do {
            try Ledger.save(context, rollbackOnFailure: true)
        } catch {
            self.error = .unknownError("Couldn't update this payee. Please try again.")
        }
    }

    private func reset() {
        nickname = ""
        accountNumber = ""
        confirmAccountNumber = ""
        ifscCode = ""
        upiId = ""
        resolvedBranch = nil
        lookupError = nil
    }
}

