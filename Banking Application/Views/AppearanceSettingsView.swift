import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
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
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Label("Liquid Glass", systemImage: "switch.2")
                                .font(.headline)
                            Text("iOS 27 lets you slide glass from ultraclear to fully tinted in Settings → Appearance → Liquid Glass. BankSecure uses the system material for tab bars, the assistant accessory, and controls, so that slider applies here automatically.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
            .bankSoftScrollEdges()
            .navigationTitle("Appearance")
            .bankInlineNavigationTitle()
            .accessibilityElement(children: .contain)
            .swipeDownToDismiss()
    }
}

struct AppearanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AppearanceSettingsView()
    }
}