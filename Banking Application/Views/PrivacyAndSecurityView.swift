import SwiftUI

struct PrivacyAndSecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authenticationService: AuthenticationService
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
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

                            Divider()

                            NavigationLink("Set duress passcode") {
                                DuressPasscodeView()
                                    .environmentObject(authenticationService)
                            }
                            .font(.body)
                        }
                        .padding()
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Label("Alerts", systemImage: "bell.fill")
                                .font(.headline)
                            Text("Transaction, low-balance, and marketing alerts live under Notifications so they are not configured in two places.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            NavigationLink {
                                NotificationsSettingsView()
                            } label: {
                                Text("Open notification settings")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .padding()
                    }
                }
                .padding(.vertical)
            }
            .bankSoftScrollEdges()
            .navigationTitle("Privacy & Security")
            .bankInlineNavigationTitle()
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
