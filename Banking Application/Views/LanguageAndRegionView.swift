import SwiftUI

struct LanguageAndRegionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var languageSelection = 0
    let languageOptions = ["English (US)", "English (UK)", "Spanish", "French", "German"]
    @State private var regionSelection = 0
    let regionOptions = ["United States", "United Kingdom", "Canada", "Australia", "India"]
    @State private var dateFormatSelection = 0
    private let dateFormatOptions = ["MM/DD/YYYY", "DD/MM/YYYY", "YYYY/MM/DD"]
    @State private var timeFormatSelection = 0
    private let timeFormatOptions = ["12-Hour", "24-Hour"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SettingsSection(title: "Language") {
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
                    
                    SettingsSection(title: "Region") {
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
                    
                    SettingsSection(title: "Date Format") {
                        Picker("Date Format", selection: $dateFormatSelection) {
                            ForEach(0..<dateFormatOptions.count, id: \.self) { index in
                                Text(dateFormatOptions[index]).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: dateFormatSelection) {
                            HapticFeedbackService.shared.lightImpact()
                        }
                    }
                    
                    SettingsSection(title: "Time Format") {
                        Picker("Time Format", selection: $timeFormatSelection) {
                            ForEach(0..<timeFormatOptions.count, id: \.self) { index in
                                Text(timeFormatOptions[index]).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: timeFormatSelection) {
                            HapticFeedbackService.shared.lightImpact()
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Language & Region")
            .toolbar {
                Button("Close") { dismiss() }
                    .accessibilityLabel("Close language settings")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct LanguageAndRegionView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageAndRegionView()
    }
}