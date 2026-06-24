import SwiftUI

struct PrivacyAndSecurityView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isFaceIDEnabled = true
    @State private var isPasscodeLockEnabled = true
    @State private var isTransactionNotificationsEnabled = true
    @State private var isMarketingNotificationsEnabled = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SettingsSection(title: "Biometric Authentication") {
                        Toggle("Face ID", isOn: $isFaceIDEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .onChange(of: isFaceIDEnabled) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                            .accessibilityLabel("Face ID enabled")
                    }
                    
                    SettingsSection(title: "Device Security") {
                        Toggle("App Passcode Lock", isOn: $isPasscodeLockEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .onChange(of: isPasscodeLockEnabled) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                            .accessibilityLabel("App Passcode Lock enabled")
                    }
                    
                    SettingsSection(title: "Notifications") {
                        Toggle("Transaction Notifications", isOn: $isTransactionNotificationsEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .onChange(of: isTransactionNotificationsEnabled) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                            .accessibilityLabel("Transaction Notifications enabled")
                        
                        Toggle("Marketing & Promotions", isOn: $isMarketingNotificationsEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .onChange(of: isMarketingNotificationsEnabled) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                            .accessibilityLabel("Marketing & Promotions enabled")
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Privacy & Security")
            .toolbar {
                Button("Close") { dismiss() }
                    .accessibilityLabel("Close privacy settings")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct PrivacyAndSecurityView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyAndSecurityView()
    }
}