import SwiftUI
import Combine

struct ProfileView: View {
    @EnvironmentObject var authenticationService: AuthenticationService
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingEditProfile = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    DemoModeBanner()
                        .padding(.horizontal)

                    ProfileHeaderView(
                        name: authenticationService.user?.fullName ?? "John Doe",
                        email: authenticationService.user?.email ?? "john.doe@example.com"
                    )

                    SettingsSection(title: "Account") {
                        NavigationLink(destination: EditProfileView()) {
                            SettingsRow(icon: "person.fill", title: "Edit Profile")
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsSection(title: "Security") {
                        NavigationLink(destination: ChangePasscodeView()) {
                            SettingsRow(icon: "key.fill", title: "Change Passcode")
                        }
                        .buttonStyle(.plain)

                        Toggle(isOn: $settings.isBiometricsEnabled) {
                            SettingsRow(
                                icon: authenticationService.biometryTypeString == "Face ID" ? "faceid" : "touchid",
                                title: useBiometricsText,
                                showsChevron: false
                            )
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color.bankPrimary))
                        .disabled(!authenticationService.canUseBiometrics)
                        .padding(.trailing, 8)
                        .onChange(of: settings.isBiometricsEnabled) { _, _ in
                            HapticFeedbackService.shared.lightImpact()
                        }
                        .accessibilityLabel("\(useBiometricsText) unlock enabled")

                        NavigationLink(destination: PrivacyAndSecurityView()) {
                            SettingsRow(icon: "lock.shield.fill", title: "Privacy & Security")
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsSection(title: "Preferences") {
                        NavigationLink(destination: NotificationsSettingsView()) {
                            SettingsRow(icon: "bell.fill", title: "Notifications")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: AppearanceSettingsView()) {
                            SettingsRow(icon: "paintbrush.fill", title: "Appearance")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: LanguageAndRegionView()) {
                            SettingsRow(icon: "globe", title: "Language & Region")
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsSection(title: "Legal") {
                        NavigationLink(destination: TermsOfServiceView()) {
                            SettingsRow(icon: "doc.text.fill", title: "Terms of Service")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: PrivacyPolicyView()) {
                            SettingsRow(icon: "hand.raised.fill", title: "Privacy Policy")
                        }
                        .buttonStyle(.plain)
                    }

                    ModernButton(
                        title: "Sign Out",
                        systemImage: "rectangle.portrait.and.arrow.right",
                        variant: .outlined,
                        tint: Color.bankDanger
                    ) {
                        logout()
                    }
                    .padding(.horizontal)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.lg)
                }
                .padding(.vertical)
                .adaptiveContentWidth()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        // Scoped to the NavigationStack itself -- see AccountOverviewView for why.
        .transparentChrome()
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
        GlassCard(tint: Color.bankPrimary) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.bankPrimaryGradient)
                        .frame(width: 68, height: 68)
                    Text(initials)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.title3.weight(.bold))
                        .accessibilityLabel("Name: \(name)")

                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Email: \(email)")
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.lg)
        }
        .padding(.horizontal)
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased().isEmpty ? "BS" : letters.joined().uppercased()
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
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .padding(.horizontal, AppSpacing.lg)

            GlassCard {
                VStack(spacing: 0) {
                    content
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
            }
            .padding(.horizontal)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.bankPrimary)
                .frame(width: 32, height: 32)
                .background(Color.bankPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .bankHoverHighlight(AppTheme.CornerRadius.small)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthenticationService())
    }
}
