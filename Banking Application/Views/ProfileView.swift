import SwiftUI
import Combine

/// Profile tab: identity plus a single Settings hub.
/// Child screens are pushed on this stack (they must not wrap another `NavigationStack`).
struct ProfileView: View {
    @EnvironmentObject var authenticationService: AuthenticationService
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        EditProfileView()
                    } label: {
                        ProfileHeaderView(
                            name: displayName,
                            email: displayEmail
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section("Security") {
                    NavigationLink {
                        ChangePasscodeView()
                    } label: {
                        SettingsRow(icon: "key.fill", title: "Passcode", subtitle: "Change your 4-digit app PIN", showsChevron: false)
                    }

                    Toggle(isOn: $settings.isBiometricsEnabled) {
                        SettingsRow(
                            icon: biometricsIcon,
                            title: useBiometricsText,
                            subtitle: authenticationService.canUseBiometrics
                                ? "Unlock with biometrics"
                                : "Not available on this device",
                            showsChevron: false
                        )
                    }
                    .tint(Color.bankPrimary)
                    .disabled(!authenticationService.canUseBiometrics)
                    .onChange(of: settings.isBiometricsEnabled) { _, _ in
                        HapticFeedbackService.shared.lightImpact()
                    }
                    .accessibilityLabel("\(useBiometricsText) unlock enabled")

                    NavigationLink {
                        PrivacyAndSecurityView()
                    } label: {
                        SettingsRow(
                            icon: "lock.shield.fill",
                            title: "Privacy & Security",
                            subtitle: settings.isPasscodeLockEnabled ? "App lock on" : "App lock off",
                            showsChevron: false
                        )
                    }
                }

                Section("Preferences") {
                    NavigationLink {
                        NotificationsSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "bell.fill",
                            title: "Notifications",
                            subtitle: settings.isTransactionNotificationsEnabled ? "Transaction alerts on" : "Transaction alerts off",
                            showsChevron: false
                        )
                    }

                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "paintbrush.fill",
                            title: "Appearance",
                            subtitle: settings.appearanceMode.rawValue,
                            showsChevron: false
                        )
                    }

                    NavigationLink {
                        LanguageAndRegionView()
                    } label: {
                        SettingsRow(
                            icon: "globe",
                            title: "Language & Region",
                            subtitle: "\(settings.languageLabel) · \(settings.regionLabel)",
                            showsChevron: false
                        )
                    }

                    Toggle(isOn: $settings.hideBalances) {
                        SettingsRow(
                            icon: settings.hideBalances ? "eye.slash.fill" : "eye.fill",
                            title: "Hide balances",
                            subtitle: "Mask amounts on Home",
                            showsChevron: false
                        )
                    }
                    .tint(Color.bankPrimary)
                    .onChange(of: settings.hideBalances) { _, _ in
                        HapticFeedbackService.shared.lightImpact()
                    }
                }

                Section("Banking plus") {
                    NavigationLink {
                        AdvancedBankingHub()
                    } label: {
                        SettingsRow(icon: "sparkles", title: "Advanced features", subtitle: "Goals, wires, statements", showsChevron: false)
                    }
                    NavigationLink {
                        DeviceManagementView()
                    } label: {
                        SettingsRow(icon: "laptopcomputer.and.iphone", title: "Devices", subtitle: "Sessions on this Apple ID", showsChevron: false)
                    }
                    NavigationLink {
                        SupportHandoffView()
                    } label: {
                        SettingsRow(icon: "lifepreserver", title: "Support", subtitle: "Help and live handoff", showsChevron: false)
                    }
                }

                Section("Legal") {
                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        SettingsRow(icon: "doc.text.fill", title: "Terms of Service", showsChevron: false)
                    }
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        SettingsRow(icon: "hand.raised.fill", title: "Privacy Policy", showsChevron: false)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        authenticationService.logout()
                    } label: {
                        SettingsRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: "Sign Out",
                            showsChevron: false
                        )
                    }
                } footer: {
                    Text("BankSecure is a demo. No real money moves. Liquid Glass follows Settings → Appearance on iOS 27.")
                        .font(.caption)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .bankSoftScrollEdges()
            .navigationTitle("Settings")
        }
        .transparentChrome()
        .accessibilityElement(children: .contain)
    }

    private var displayName: String {
        let name = authenticationService.user?.fullName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Your account" : name
    }

    private var displayEmail: String {
        let email = authenticationService.user?.email.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return email.isEmpty ? "Add an email in Edit Profile" : email
    }

    private var useBiometricsText: String {
        authenticationService.biometryTypeString.isEmpty ? "Biometrics" : authenticationService.biometryTypeString
    }

    private var biometricsIcon: String {
        authenticationService.biometryTypeString == "Face ID" ? "faceid" : "touchid"
    }
}

struct ProfileHeaderView: View {
    let name: String
    let email: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.bankPrimaryGradient)
                    .frame(width: 64, height: 64)
                Text(initials)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Edit profile")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.bankPrimary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(email). Edit profile")
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased().isEmpty ? "BS" : letters.joined().uppercased()
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
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthenticationService())
    }
}
