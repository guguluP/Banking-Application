import SwiftUI

struct PrivacyAndSecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authenticationService: AuthenticationService
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                    DemoModeBanner()
                        .padding(.horizontal)

                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Biometric Authentication", systemImage: "faceid")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Toggle(isOn: $settings.isBiometricsEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(authenticationService.biometryTypeString.isEmpty
                                         ? "Biometrics"
                                         : authenticationService.biometryTypeString)
                                        .font(.body)
                                    Text(authenticationService.canUseBiometrics
                                         ? "Use biometrics to unlock the app"
                                         : "Not available on this device")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color.bankPrimary))
                            .disabled(!authenticationService.canUseBiometrics)
                            .onChange(of: settings.isBiometricsEnabled) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                            .accessibilityLabel("Biometric unlock enabled")
                        }
                        .padding()
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Device Security", systemImage: "lock.fill")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Toggle(isOn: $settings.isPasscodeLockEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("App Passcode Lock")
                                        .font(.body)
                                    Text("Require passcode or biometrics when the app opens")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color.bankPrimary))
                            .onChange(of: settings.isPasscodeLockEnabled) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                            .accessibilityLabel("App Passcode Lock enabled")
                        }
                        .padding()
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Notifications", systemImage: "bell.fill")
                                .font(.headline)
                                .foregroundColor(.primary)

                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                Toggle(isOn: $settings.isTransactionNotificationsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Transaction Notifications")
                                            .font(.body)
                                        Text("Get alerted on every transaction")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color.bankPrimary))
                                .onChange(of: settings.isTransactionNotificationsEnabled) {
                                    HapticFeedbackService.shared.lightImpact()
                                }

                                Divider()

                                Toggle(isOn: $settings.isMarketingNotificationsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Marketing & Promotions")
                                            .font(.body)
                                        Text("Offers and promotions (demo preference only)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color.bankPrimary))
                                .onChange(of: settings.isMarketingNotificationsEnabled) {
                                    HapticFeedbackService.shared.lightImpact()
                                }
                            }
                        }
                        .padding()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Privacy & Security")
        }
        .accessibilityElement(children: .contain)
        .swipeDownToDismiss()
    }
}

struct PrivacyAndSecurityView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyAndSecurityView()
            .environmentObject(AuthenticationService())
    }
}
