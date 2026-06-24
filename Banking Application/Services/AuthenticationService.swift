import Foundation
import LocalAuthentication
import Combine
import SwiftUI

@MainActor
class AuthenticationService: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var errorMessage: String?
    @Published var user: User?
    @Published var canUseBiometrics: Bool = false
    @Published var biometryTypeString: String = ""
    
    private let context = LAContext()
    private var cancellables = Set<AnyCancellable>()
    
    var mockUser: User {
        User(
            id: "1",
            firstName: "John",
            lastName: "Doe",
            email: "john.doe@example.com",
            phoneNumber: "+91 98765 43210",
            dateOfBirth: Date(timeIntervalSince1970: 631152000),
            address: Address(
                street: "123 Main St",
                city: "Bhubaneswar",
                state: "OD",
                postalCode: "751001",
                country: "India"
            ),
            isActive: true,
            createdAt: Date(),
            lastLogin: nil
        )
    }
    
    init() {
        checkBiometricsAvailability()
    }
    
    private func checkBiometricsAvailability() {
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if canEvaluate {
            canUseBiometrics = true
            switch context.biometryType {
            case .faceID:
                biometryTypeString = "Face ID"
            case .touchID:
                biometryTypeString = "Touch ID"
            case .opticID:
                biometryTypeString = "Optic ID"
            default:
                biometryTypeString = "Biometrics"
            }
        } else {
            canUseBiometrics = false
            biometryTypeString = "Passcode"
        }
    }
    
    @MainActor
    func authenticateWithBiometrics(completion: @escaping (Bool) -> Void) {
        guard canUseBiometrics else {
            completion(false)
            return
        }

        isAuthenticating = true
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Sign in to BankSecure") { [weak self] success, error in
            Task { @MainActor in
                self?.isAuthenticating = false

                if success {
                    self?.completeAuthentication()
                } else {
                    self?.errorMessage = error?.localizedDescription ?? "Authentication failed"
                }
            }
            completion(success)
        }
    }
    
    @MainActor
    func authenticateWithPasscode(completion: @escaping (Bool) -> Void) {
        isAuthenticating = true

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Enter your device passcode") { [weak self] success, error in
            Task { @MainActor in
                self?.isAuthenticating = false

                if success {
                    self?.completeAuthentication()
                } else {
                    self?.errorMessage = error?.localizedDescription ?? "Authentication failed"
                }
            }
            completion(success)
        }
    }
    
    @MainActor
    private func completeAuthentication() {
        isAuthenticated = true
        user = mockUser
        errorMessage = nil
    }
    
    @MainActor
    func login(passcode: String) {
        // WARNING: Any 4-digit passcode is accepted here. This is simulator-mode only
        // and must NOT be deployed to production. Replace with a real authentication
        // call (e.g. backend JWT exchange) before release.
        guard !passcode.isEmpty, passcode.count >= 4 else {
            errorMessage = "Please enter a valid passcode"
            return
        }
        
        isAuthenticating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.completeAuthentication()
            self.isAuthenticating = false
        }
    }
    
    @MainActor
    func logout() {
        isAuthenticated = false
        user = nil
        errorMessage = nil
    }
}
