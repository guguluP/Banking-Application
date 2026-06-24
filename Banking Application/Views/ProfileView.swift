import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authenticationService: AuthenticationService
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var isUsingBiometrics = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    ProfileHeaderView(
                        name: authenticationService.user?.fullName ?? "John Doe",
                        email: authenticationService.user?.email ?? "john.doe@example.com"
                    )
                    
                    SettingsSection(title: "Account") {
                        NavigationLink(destination: EditProfileView()) {
                            SettingsRow(icon: "person", title: "Edit Profile")
                        }
                    }
                    
                    SettingsSection(title: "Security") {
                        NavigationLink(destination: ChangePasscodeView()) {
                            SettingsRow(icon: "key", title: "Change Passcode")
                        }
                        
                        Toggle(useBiometricsText, isOn: $isUsingBiometrics)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .onChange(of: isUsingBiometrics) { _, newValue in
                                HapticFeedbackService.shared.lightImpact()
                                UserDefaults.standard.set(newValue, forKey: "useBiometrics")
                            }
                        
                        NavigationLink(destination: PrivacyAndSecurityView()) {
                            SettingsRow(icon: "lock.shield", title: "Privacy & Security")
                        }
                    }
                    
                    SettingsSection(title: "Preferences") {
                        NavigationLink(destination: NotificationsSettingsView()) {
                            SettingsRow(icon: "bell", title: "Notifications")
                        }
                        
                        NavigationLink(destination: AppearanceSettingsView()) {
                            SettingsRow(icon: "paintbrush", title: "Appearance")
                        }
                        
                        NavigationLink(destination: LanguageAndRegionView()) {
                            SettingsRow(icon: "globe", title: "Language & Region")
                        }
                    }
                    
                    SettingsSection(title: "Legal") {
                        NavigationLink(destination: TermsOfServiceView()) {
                            SettingsRow(icon: "doc.text", title: "Terms of Service")
                        }
                        
                        NavigationLink(destination: PrivacyPolicyView()) {
                            SettingsRow(icon: "hand.raised", title: "Privacy Policy")
                        }
                    }
                    
                    ModernButton(
                        title: "Sign Out",
                        systemImage: "rectangle.portrait.and.arrow.right",
                        variant: .glass
                    ) {
                        logout()
                    }
                    .foregroundColor(Color.bankDanger)
                    .padding(.horizontal)
                    .padding(.top, AppSpacing.lg)
                }
                .padding(.vertical)
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .onAppear {
                isUsingBiometrics = UserDefaults.standard.bool(forKey: "useBiometrics")
            }
        }
        .accessibilityElement(children: .contain)
    }
    
    private var useBiometricsText: String {
        authenticationService.biometryTypeString.isEmpty ? "Face ID" : authenticationService.biometryTypeString
    }
    
    private func logout() {
        authenticationService.logout()
    }
}

struct ProfileHeaderView: View {
    let name: String
    let email: String
    
    var body: some View {
        GlassCard {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color.bankPrimary)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .accessibilityLabel("Name: \(name)")
                    
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Email: \(email)")
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            GlassCard {
                VStack(spacing: 0) {
                    content
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String? = nil
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Color.bankPrimary)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthenticationService())
    }
}