import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Appearance", systemImage: "paintbrush.fill")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            PillSegmentedControl(
                                selection: $settings.appearanceMode,
                                items: AppearanceMode.allCases,
                                icon: { $0.systemImage }
                            )
                            .onChange(of: settings.appearanceMode) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                        }
                        .padding()
                    }
                    
                    GlassCard {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "app.fill")
                                .font(.system(size: 30))
                                .foregroundColor(Color.bankPrimary)
                                .symbolRenderingMode(.hierarchical)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("App Icon")
                                    .font(.headline)
                                Text("BankSecure")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Appearance")
        }
        .accessibilityElement(children: .contain)
        .swipeDownToDismiss()
    }
}

struct AppearanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AppearanceSettingsView()
    }
}