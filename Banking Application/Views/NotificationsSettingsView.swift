import SwiftUI

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("Preferences are saved on this device. Push delivery is not wired in demo mode.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Transaction Alerts", systemImage: "bell.badge.fill")
                                .font(.headline)
                                .foregroundColor(.primary)

                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                Toggle(isOn: $settings.isTransactionNotificationsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("All Transactions")
                                            .font(.body)
                                        Text("Notified immediately on every transaction")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color.bankPrimary))
                                .onChange(of: settings.isTransactionNotificationsEnabled) {
                                    HapticFeedbackService.shared.lightImpact()
                                }

                                Divider()

                                Toggle(isOn: $settings.isLowBalanceAlertsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Low Balance")
                                            .font(.body)
                                        Text("When balance falls below threshold")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color(red: 1, green: 0.65, blue: 0)))
                                .onChange(of: settings.isLowBalanceAlertsEnabled) {
                                    HapticFeedbackService.shared.lightImpact()
                                }

                                Divider()

                                Toggle(isOn: $settings.isLargeTransactionAlertsEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Large Transactions")
                                            .font(.body)
                                        Text("For transactions above ₹50,000")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color.bankDanger))
                                .onChange(of: settings.isLargeTransactionAlertsEnabled) {
                                    HapticFeedbackService.shared.lightImpact()
                                }
                            }
                        }
                        .padding()
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Summary & Reports", systemImage: "chart.bar.fill")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Toggle(isOn: $settings.isWeeklySummaryEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Weekly Summary")
                                        .font(.body)
                                    Text("Every Monday morning at 8 AM")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color.bankPrimary))
                            .onChange(of: settings.isWeeklySummaryEnabled) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                        }
                        .padding()
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Marketing", systemImage: "megaphone.fill")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Toggle(isOn: $settings.isMarketingNotificationsEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Promotional Offers")
                                        .font(.body)
                                    Text("Exclusive deals and rewards")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .onChange(of: settings.isMarketingNotificationsEnabled) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                        }
                        .padding()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Notifications")
        }
        .accessibilityElement(children: .contain)
        .swipeDownToDismiss()
    }
}

struct NotificationsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationsSettingsView()
    }
}
