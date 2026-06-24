import SwiftUI

struct ChangePasscodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPasscode: String = ""
    @State private var newPasscode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var error: AppError?
    @State private var currentStep: PasscodeStep = .current
    
    enum PasscodeStep {
        case current, new, confirm
    }
    
    private let maxPasscodeLength = 4
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                stepTitle
                
                PasscodeDots(passcode: currentPasscodeBinding)
                    .padding(.vertical, AppSpacing.xl)
                    .accessibilityLabel("\(passcodeTitle): \(passcodeDotsDescription)")
                
                PasscodeKeypad(passcode: currentPasscodeBinding, onDelete: deletePasscode)
                
                if let error = error {
                    ErrorBannerModern(error: error)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top, AppSpacing.xxl)
            .navigationTitle("Change Passcode")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel passcode change")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        validateAndSave()
                    }
                    .disabled(!canSave)
                    .accessibilityLabel("Save passcode change")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
    
    private var stepTitle: some View {
        VStack(spacing: 8) {
            switch currentStep {
            case .current:
                Text("Enter Current Passcode")
            case .new:
                Text("Enter New Passcode")
            case .confirm:
                Text("Confirm New Passcode")
            }
        }
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
    }
    
    private var passcodeTitle: String {
        switch currentStep {
        case .current: return "Current Passcode"
        case .new: return "New Passcode"
        case .confirm: return "Confirm Passcode"
        }
    }
    
    private var passcodeDotsDescription: String {
        "\(currentPasscodeBinding.wrappedValue.count) of \(maxPasscodeLength) digits entered"
    }
    
    private var currentPasscodeBinding: Binding<String> {
        switch currentStep {
        case .current: return $currentPasscode
        case .new: return $newPasscode
        case .confirm: return $confirmPasscode
        }
    }
    
    private func deletePasscode() {
        if !currentPasscodeBinding.wrappedValue.isEmpty {
            currentPasscodeBinding.wrappedValue.removeLast()
            HapticFeedbackService.shared.lightImpact()
        }
    }
    
    private var canSave: Bool {
        switch currentStep {
        case .current:
            !currentPasscode.isEmpty && currentPasscode.count == maxPasscodeLength
        case .new:
            newPasscode.count == maxPasscodeLength
        case .confirm:
            confirmPasscode.count == maxPasscodeLength && newPasscode == confirmPasscode
        }
    }
    
    private func validateAndSave() {
        error = nil
        
        switch currentStep {
        case .current:
            let storedPasscode = UserDefaults.standard.string(forKey: "userPasscode") ?? ""
            guard currentPasscode == storedPasscode else {
                error = .authenticationFailed
                HapticFeedbackService.shared.errorOccurred()
                currentPasscode = ""
                return
            }
            currentStep = .new
        case .new:
            guard newPasscode.count == maxPasscodeLength else {
                error = .invalidInput
                HapticFeedbackService.shared.errorOccurred()
                return
            }
            currentStep = .confirm
        case .confirm:
            guard newPasscode == confirmPasscode else {
                error = .unknownError("Passcodes do not match")
                HapticFeedbackService.shared.errorOccurred()
                confirmPasscode = ""
                return
            }
            UserDefaults.standard.set(newPasscode, forKey: "userPasscode")
            HapticFeedbackService.shared.success()
            dismiss()
        }
    }
}

struct PasscodeDots: View {
    @Binding var passcode: String
    let maxDots = 4
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<maxDots, id: \.self) { index in
                Circle()
                    .stroke(passcode.count > index ? Color.bankPrimary : Color.secondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .fill(Color.bankPrimary)
                            .frame(width: 8, height: 8)
                            .opacity(passcode.count > index ? 1 : 0)
                    )
                    .scaleEffect(passcode.count == index + 1 ? 1.2 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: passcode.count)
            }
        }
    }
}

struct PasscodeKeypad: View {
    @Binding var passcode: String
    let onDelete: () -> Void
    
    let buttonSize: CGFloat = 70
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3) { row in
                HStack(spacing: 12) {
                    ForEach(1..<4) { column in
                        let number = row * 3 + column
                        Button(action: {
                            if passcode.count < 4 {
                                passcode.append(String(number))
                                HapticFeedbackService.shared.lightImpact()
                            }
                        }) {
                            Text("\(number)")
                                .font(.title)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color(UIColor.systemGroupedBackground))
                                .cornerRadius(35)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(passcode.count >= 4)
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button(action: onDelete) {
                    Image(systemName: "delete.backward")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color(UIColor.systemGroupedBackground))
                        .cornerRadius(35)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(passcode.isEmpty)
                
                Button(action: {
                    if passcode.count < 4 {
                        passcode.append("0")
                        HapticFeedbackService.shared.lightImpact()
                    }
                }) {
                    Text("0")
                        .font(.title)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color(UIColor.systemGroupedBackground))
                        .cornerRadius(35)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(passcode.count >= 4)
            }
        }
    }
}

struct ChangePasscodeView_Previews: PreviewProvider {
    static var previews: some View {
        ChangePasscodeView()
    }
}