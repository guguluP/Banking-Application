import SwiftUI

struct LoginView: View {
    @Environment(AuthenticationService.self) var authenticationService
    @State private var passcode = ""
    @State private var error: AppError?
    @State private var shakeTrigger = false
    @FocusState private var isTextFieldFocused: Bool

    let maxPasscodeLength = 4

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
                .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        brandHeader

                        GlassCard(tint: Color.bankPrimary) {
                            VStack(spacing: AppSpacing.lg) {
                                Text("Enter Passcode")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)

                                passcodeDots
                                    .background { passcodeCapture }

                                KeypadView(passcode: $passcode, onDelete: {
                                    if !passcode.isEmpty {
                                        passcode.removeLast()
                                        HapticFeedbackService.shared.lightImpact()
                                    }
                                })
                                .disabled(isLockedOut)
                                .opacity(isLockedOut ? 0.4 : 1)
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, AppSpacing.xl)
                            .padding(.horizontal, AppSpacing.lg)
                        }

                        if authenticationService.isBiometricsLoginEnabled {
                            biometricsButton
                                .frame(maxWidth: .infinity)
                        }

                        DemoModeBanner(compact: true)

                        if authenticationService.isAuthenticating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .accessibilityLabel("Signing in")
                        }

                        if let error {
                            ErrorBannerModern(error: error)
                        }

                        if isLockedOut {
                            LockoutBanner(secondsRemaining: authenticationService.lockoutRemainingSeconds)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else if let message = authenticationService.errorMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(Color.bankDanger)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .transition(.opacity)
                        }

                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.xl)
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height, alignment: .center)
                }
                .scrollBounceBehavior(.basedOnSize)
                .bankSoftScrollEdges()
            }
        }
        .offset(x: shakeTrigger ? 10 : 0)
        .animation(shakeTrigger ? .easeInOut(duration: 0.1).repeatCount(5) : .default, value: shakeTrigger)
        .animation(AppTheme.Animation.standard, value: authenticationService.lockoutRemainingSeconds)
        .animation(.easeInOut(duration: 0.2), value: authenticationService.errorMessage)
        .onAppear { isTextFieldFocused = true }
        .onChange(of: authenticationService.isAuthenticated) { _, authenticated in
            if authenticated { isTextFieldFocused = false }
        }
        .onChange(of: passcode) { _, newValue in
            if newValue.count == maxPasscodeLength {
                isTextFieldFocused = false
                hideKeyboard()
                attemptLogin()
            }
        }
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") { isTextFieldFocused = false }
                    .accessibilityLabel("Dismiss keyboard")
            }
        }
        .sensitiveScreenShield()
    }

    private var brandHeader: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.bankPrimary.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Color.bankPrimaryGradient)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityLabel("BankSecure Logo")
            }

            Text("BankSecure")
                .font(.largeTitle())
                .accessibilityAddTraits(.isHeader)

            Text("Your trusted banking companion")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var passcodeDots: some View {
        HStack(spacing: 18) {
            ForEach(0..<maxPasscodeLength, id: \.self) { index in
                Circle()
                    .stroke(
                        passcode.count > index ? Color.bankPrimary : Color.secondary.opacity(0.28),
                        lineWidth: 2
                    )
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .fill(Color.bankPrimary)
                            .frame(width: 10, height: 10)
                            .opacity(passcode.count > index ? 1 : 0)
                    )
                    .scaleEffect(passcode.count == index + 1 ? 1.18 : 1)
                    .animation(AppTheme.Animation.standard, value: passcode.count)
            }
        }
        .accessibilityLabel("Passcode entry: \(passcode.count) of \(maxPasscodeLength) digits entered")
    }

    /// Hardware keyboard entry. Kept out of the stack so a Mac text field cannot stretch the card.
    private var passcodeCapture: some View {
        SecureField("", text: $passcode)
            .textContentType(.oneTimeCode)
            .focused($isTextFieldFocused)
            .onAppear { isTextFieldFocused = true }
            .onChange(of: passcode) { _, newValue in
                let digits = String(newValue.filter(\.isNumber).prefix(maxPasscodeLength))
                if digits != newValue { passcode = digits }
            }
            .submitLabel(.done)
            .onSubmit {
                if isFormValid { attemptLogin() }
            }
            #if os(iOS) && !targetEnvironment(macCatalyst)
            .keyboardType(.numberPad)
            #endif
            .opacity(0)
            .frame(width: 1, height: 1)
            .accessibilityHidden(true)
    }

    private var biometricsButton: some View {
        Button(action: {
            hideKeyboard()
            authenticationService.authenticateWithBiometrics { success in
                if !success {
                    error = .biometricFailed
                    shakeTrigger = true
                    HapticFeedbackService.shared.errorOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        shakeTrigger = false
                    }
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: authenticationService.biometryTypeString == "Face ID" ? "faceid" : "touchid")
                    .symbolRenderingMode(.hierarchical)
                Text("Use \(authenticationService.biometryTypeString)")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .glassControl(cornerRadius: AppTheme.CornerRadius.pill, tint: Color.bankPrimary)
        }
        .buttonStyle(ScalePressButtonStyle())
        .disabled(authenticationService.isAuthenticating || isLockedOut)
        .opacity(isLockedOut ? 0.4 : 1)
        .accessibilityLabel("Sign in with \(authenticationService.biometryTypeString)")
    }

    private var isFormValid: Bool { !passcode.isEmpty && passcode.count >= 4 }
    private var isLockedOut: Bool { authenticationService.lockoutRemainingSeconds > 0 }

    private func attemptLogin() {
        guard !isLockedOut else { return }
        error = nil
        hideKeyboard()
        authenticationService.login(passcode: passcode)
        passcode = ""
    }

    private func hideKeyboard() {
        KeyboardDismiss.resign()
    }
}

struct KeypadView: View {
    @Binding var passcode: String
    let onDelete: () -> Void

    private var buttonSize: CGFloat {
        PlatformUI.isMac ? 64 : AppTheme.Control.keypadButton
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(buttonSize), spacing: 12, alignment: .center), count: 3)
    }

    private var gridWidth: CGFloat { buttonSize * 3 + 24 }

    var body: some View {
        LiquidGlass.container(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...9, id: \.self) { number in
                    keypadButton(label: "\(number)") {
                        if passcode.count < 4 {
                            passcode.append(String(number))
                            HapticFeedbackService.shared.lightImpact()
                        }
                    }
                    .disabled(passcode.count >= 4)
                }

                Button(action: onDelete) {
                    Image(systemName: "delete.backward")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(width: buttonSize, height: buttonSize)
                        .glassControl(cornerRadius: buttonSize / 2)
                }
                .buttonStyle(ScalePressButtonStyle())
                .accessibilityLabel("Delete")

                keypadButton(label: "0") {
                    if passcode.count < 4 {
                        passcode.append("0")
                        HapticFeedbackService.shared.lightImpact()
                    }
                }
                .disabled(passcode.count >= 4)

                Color.clear
                    .frame(width: buttonSize, height: buttonSize)
                    .accessibilityHidden(true)
            }
            .frame(width: gridWidth)
        }
        .frame(width: gridWidth)
    }

    private func keypadButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: buttonSize, height: buttonSize)
                .glassControl(cornerRadius: buttonSize / 2)
        }
        .buttonStyle(ScalePressButtonStyle())
    }
}

struct LockoutBanner: View {
    let secondsRemaining: Int

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                .foregroundStyle(Color.bankWarning)
            Text("Too many attempts. Try again in \(secondsRemaining)s.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            Color.bankWarning.opacity(0.14),
            in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environment(AuthenticationService())
    }
}
