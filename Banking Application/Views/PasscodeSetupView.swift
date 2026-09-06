import SwiftUI
import Combine

/// Shown exactly once, the first time the app runs on a device (i.e. before any
/// passcode hash exists in the Keychain). Asks the person to choose a 4-digit
/// passcode, then asks them to confirm it, and stores only its salted hash.
struct PasscodeSetupView: View {
    @EnvironmentObject var authenticationService: AuthenticationService

    private enum Stage: Equatable {
        case create
        case confirm
    }

    @State private var stage: Stage = .create
    @State private var firstEntry = ""
    @State private var passcode = ""
    @State private var errorText: String?
    @State private var shakeTrigger = false
    @FocusState private var isFocused: Bool

    let maxPasscodeLength = 4

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                Spacer().frame(height: AppSpacing.xxxl)

                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 56))
                        .foregroundColor(Color.bankPrimary)
                        .transition(.scale.combined(with: .opacity))
                        .id(stage == .create ? "create-icon" : "confirm-icon")

                    Text(stage == .create ? "Create a Passcode" : "Confirm Passcode")
                        .font(.title2.weight(.semibold))

                    Text(stage == .create
                         ? "You'll use this 4-digit passcode to unlock BankSecure."
                         : "Enter it once more to confirm.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }

                GlassCard {
                    VStack(spacing: AppSpacing.lg) {
                        HStack(spacing: 16) {
                            ForEach(0..<maxPasscodeLength, id: \.self) { index in
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
                        .accessibilityLabel("Passcode entry: \(passcode.count) of \(maxPasscodeLength) digits entered")

                        KeypadView(passcode: $passcode, onDelete: {
                            if !passcode.isEmpty {
                                passcode.removeLast()
                                HapticFeedbackService.shared.lightImpact()
                            }
                        })
                    }
                    .padding(.vertical, AppSpacing.xl)
                    .padding(.horizontal, AppSpacing.lg)
                }

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .offset(x: shakeTrigger ? 10 : 0)
        .animation(shakeTrigger ? .easeInOut(duration: 0.1).repeatCount(5) : .default, value: shakeTrigger)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: stage)
        .onChange(of: passcode) { _, newValue in
            if newValue.count > maxPasscodeLength {
                passcode = String(newValue.prefix(maxPasscodeLength))
            }
            if newValue.count == maxPasscodeLength {
                advance()
            }
        }
    }

    private func advance() {
        switch stage {
        case .create:
            firstEntry = passcode
            passcode = ""
            errorText = nil
            withAnimation { stage = .confirm }

        case .confirm:
            if passcode == firstEntry {
                if authenticationService.setPasscode(passcode) {
                    HapticFeedbackService.shared.success()
                } else {
                    errorText = "Couldn't save your passcode. Please try again."
                    resetToCreate()
                }
            } else {
                errorText = "Passcodes didn't match. Try again."
                shakeTrigger = true
                HapticFeedbackService.shared.errorOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    shakeTrigger = false
                    resetToCreate()
                }
            }
        }
    }

    private func resetToCreate() {
        passcode = ""
        firstEntry = ""
        withAnimation { stage = .create }
    }
}

struct PasscodeSetupView_Previews: PreviewProvider {
    static var previews: some View {
        PasscodeSetupView()
            .environmentObject(AuthenticationService())
    }
}
