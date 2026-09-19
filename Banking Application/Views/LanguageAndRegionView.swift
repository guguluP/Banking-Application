import SwiftUI

struct LanguageAndRegionView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                GlassCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Label("Language", systemImage: "globe")
                            .font(.headline)

                        Picker("Language", selection: $settings.languageIndex) {
                            ForEach(AppSettings.languageOptions.indices, id: \.self) { index in
                                Text(AppSettings.languageOptions[index]).tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: settings.languageIndex) {
                            HapticFeedbackService.shared.lightImpact()
                        }

                        Text("Display language for labels in this demo. Currency stays Indian Rupees.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Label("Region", systemImage: "map.fill")
                            .font(.headline)

                        Picker("Region", selection: $settings.regionIndex) {
                            ForEach(AppSettings.regionOptions.indices, id: \.self) { index in
                                Text(AppSettings.regionOptions[index]).tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: settings.regionIndex) {
                            HapticFeedbackService.shared.lightImpact()
                        }
                    }
                    .padding()
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Label("Date Format", systemImage: "calendar")
                            .font(.headline)

                        PillSegmentedControl(
                            selection: $settings.dateFormat,
                            items: BankDateFormat.allCases
                        )
                        .onChange(of: settings.dateFormat) {
                            HapticFeedbackService.shared.lightImpact()
                        }
                    }
                    .padding()
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Label("Time Format", systemImage: "clock.fill")
                            .font(.headline)

                        PillSegmentedControl(
                            selection: $settings.timeFormat,
                            items: BankTimeFormat.allCases
                        )
                        .onChange(of: settings.timeFormat) {
                            HapticFeedbackService.shared.lightImpact()
                        }
                    }
                    .padding()
                }
            }
            .padding(.vertical)
        }
        .bankSoftScrollEdges()
        .navigationTitle("Language & Region")
        .bankInlineNavigationTitle()
        .accessibilityElement(children: .contain)
        .swipeDownToDismiss()
    }
}

struct LanguageAndRegionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { LanguageAndRegionView() }
    }
}
