import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appearanceSelection = 0
    
    let appearanceOptions = ["System", "Light", "Dark"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SettingsSection(title: "Appearance") {
                        Picker("Appearance", selection: $appearanceSelection) {
                            ForEach(0..<appearanceOptions.count, id: \.self) { index in
                                Text(appearanceOptions[index]).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: appearanceSelection) {
                            HapticFeedbackService.shared.lightImpact()
                        }
                    }
                    
                    SettingsSection(title: "App Icon") {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "app.fill")
                                .font(.system(size: 30))
                                .foregroundColor(Color.bankPrimary)
                                .symbolRenderingMode(.hierarchical)
                                .accessibilityHidden(true)
                            
                            Text("BankSecure")
                                .font(.headline)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Appearance")
            .toolbar {
                Button("Close") { dismiss() }
                    .accessibilityLabel("Close appearance settings")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct AppearanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AppearanceSettingsView()
    }
}