import SwiftUI

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isTransactionAlertsEnabled = true
    @State private var isLowBalanceAlertsEnabled = true
    @State private var isLargeTransactionAlertsEnabled = true
    @State private var isWeeklySummaryEnabled = false
    @State private var isPromotionalOffersEnabled = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SettingsSection(title: "Transaction Alerts") {
                        Toggle("Transaction Alerts", isOn: $isTransactionAlertsEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .onChange(of: isTransactionAlertsEnabled) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                            .accessibilityLabel("Transaction Alerts enabled")
                        
                        Toggle("Low Balance Alerts", isOn: $isLowBalanceAlertsEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .orange))
                            .onChange(of: isLowBalanceAlertsEnabled) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                            .accessibilityLabel("Low Balance Alerts enabled")
                        
                        Toggle("Large Transaction Alerts", isOn: $isLargeTransactionAlertsEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .red))
                            .onChange(of: isLargeTransactionAlertsEnabled) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                            .accessibilityLabel("Large Transaction Alerts enabled")
                    }
                    
                    SettingsSection(title: "Summary & Reports") {
                        Toggle("Weekly Summary", isOn: $isWeeklySummaryEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .onChange(of: isWeeklySummaryEnabled) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                            .accessibilityLabel("Weekly Summary enabled")
                    }
                    
                    SettingsSection(title: "Marketing") {
                        Toggle("Promotional Offers", isOn: $isPromotionalOffersEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .onChange(of: isPromotionalOffersEnabled) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                            .accessibilityLabel("Promotional Offers enabled")
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Notifications")
            .toolbar {
                Button("Close") { dismiss() }
                    .accessibilityLabel("Close notifications settings")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct NotificationsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationsSettingsView()
    }
}