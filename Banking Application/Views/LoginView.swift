import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authenticationService: AuthenticationService
    @State private var passcode = ""
    @State private var error: AppError?
    @State private var shakeTrigger = false
    @FocusState private var isTextFieldFocused: Bool
    
    let maxPasscodeLength = 4
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.bankPrimary.opacity(0.05), Color(UIColor.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isTextFieldFocused = false
                }
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: AppSpacing.xxxl)
                
                VStack(spacing: AppSpacing.xl) {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color.bankPrimary)
                            .accessibilityLabel("BankSecure Logo")
                        
                        Text("BankSecure")
                            .font(.largeTitle())
                            .accessibilityAddTraits(.isHeader)
                        
                        Text("Your trusted banking companion")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    GlassCard {
                        VStack(spacing: AppSpacing.lg) {
                            Text("Enter Passcode")
                                .font(.headline)
                            
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
                            
                            SecureField("", text: $passcode)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.plain)
                                .frame(width: 0, height: 0)
                                .opacity(0)
                                .focused($isTextFieldFocused)
                                .onAppear {
                                    isTextFieldFocused = true
                                }
                                .onChange(of: passcode) { _, newValue in
                                    if newValue.count > maxPasscodeLength {
                                        passcode = String(newValue.prefix(maxPasscodeLength))
                                    }
                                }
                                .submitLabel(.done)
                                .onSubmit {
                                    if isFormValid {
                                        attemptLogin()
                                    }
                                }
                            
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
                    
                    if authenticationService.canUseBiometrics {
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
                            }
                            .foregroundColor(Color.bankPrimary)
                        }
                        .disabled(authenticationService.isAuthenticating)
                        .accessibilityLabel("Sign in with \(authenticationService.biometryTypeString)")
                    }
                    
                    if authenticationService.isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .accessibilityLabel("Signing in")
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                
                if let error = error {
                    ErrorBannerModern(error: error)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.lg)
                }
                
                if let error = authenticationService.errorMessage {
                    ErrorBannerModern(error: .authenticationFailed)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.lg)
                }
                
                Spacer()
                
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, AppSpacing.lg)
            }
        }
        .offset(x: shakeTrigger ? 10 : 0)
        .animation(shakeTrigger ? .easeInOut(duration: 0.1).repeatCount(5) : .default, value: shakeTrigger)
        .onAppear {
            isTextFieldFocused = true
        }
        .onChange(of: authenticationService.isAuthenticated) { _, authenticated in
            if authenticated {
                isTextFieldFocused = false
            }
        }
        .onChange(of: passcode) { _, newValue in
            if newValue.count == maxPasscodeLength {
                isTextFieldFocused = false
                hideKeyboard()
            }
        }
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") {
                    isTextFieldFocused = false
                }
                .accessibilityLabel("Dismiss keyboard")
            }
        }
    }
    
    private var isFormValid: Bool { !passcode.isEmpty && passcode.count >= 4 }
    
    private func attemptLogin() {
        error = nil
        hideKeyboard()
        authenticationService.login(passcode: passcode)
    }
    
    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

struct KeypadView: View {
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
                                .cornerRadius(AppTheme.CornerRadius.pill)
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
                        .cornerRadius(AppTheme.CornerRadius.pill)
                }
                .buttonStyle(PlainButtonStyle())
                
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
                        .cornerRadius(AppTheme.CornerRadius.pill)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(passcode.count >= 4)
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthenticationService())
    }
}