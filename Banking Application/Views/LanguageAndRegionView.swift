import SwiftUI

struct LanguageAndRegionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var languageSelection = 0
    let languageOptions = ["English (US)", "English (UK)", "Spanish", "French", "German"]
    @State private var regionSelection = 0
    let regionOptions = ["United States", "United Kingdom", "Canada", "Australia", "India"]
    @State private var dateFormatSelection: DateFormatOption = .dayMonthYear
    @State private var timeFormatSelection: TimeFormatOption = .twelveHour
    
    enum DateFormatOption: String, CaseIterable {
        case monthDayYear = "MM/DD/YYYY"
        case dayMonthYear = "DD/MM/YYYY"
        case yearMonthDay = "YYYY/MM/DD"
    }
    
    enum TimeFormatOption: String, CaseIterable {
        case twelveHour = "12-Hour"
        case twentyFourHour = "24-Hour"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.lg) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Language", systemImage: "globe")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Picker("Language", selection: $languageSelection) {
                                ForEach(0..<languageOptions.count, id: \.self) { index in
                                    Text(languageOptions[index]).tag(index)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: languageSelection) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                        }
                        .padding()
                    }
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Region", systemImage: "map.fill")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Picker("Region", selection: $regionSelection) {
                                ForEach(0..<regionOptions.count, id: \.self) { index in
                                    Text(regionOptions[index]).tag(index)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: regionSelection) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                        }
                        .padding()
                    }
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Date Format", systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            PillSegmentedControl(
                                selection: $dateFormatSelection,
                                items: DateFormatOption.allCases
                            )
                            .onChange(of: dateFormatSelection) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                        }
                        .padding()
                    }
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Label("Time Format", systemImage: "clock.fill")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            PillSegmentedControl(
                                selection: $timeFormatSelection,
                                items: TimeFormatOption.allCases
                            )
                            .onChange(of: timeFormatSelection) {
                                HapticFeedbackService.shared.lightImpact()
                            }
                        }
                        .padding()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Language & Region")
        }
        .accessibilityElement(children: .contain)
        .swipeDownToDismiss()
    }
}

struct LanguageAndRegionView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageAndRegionView()
    }
}