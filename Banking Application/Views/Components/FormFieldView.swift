import SwiftUI

struct FormFieldView: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isValid: Bool = true
    var errorMessage: String = ""
    var helpText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel

            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
                .padding(12)
                .background(Color.bankGroupedBackground)
                .cornerRadius(8)
                .border(isValid ? Color.clear : Color.red, width: 1)
            
            if !helpText.isEmpty {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !errorMessage.isEmpty && !isValid {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(errorMessage)
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
    }

    /// Only shows a checkmark once there's actual text to have validated —
    /// otherwise an empty, untouched field would misleadingly show green.
    /// Passing an empty string as `Label`'s systemImage (the previous
    /// behavior for the invalid case) also isn't a valid SF Symbol name.
    @ViewBuilder
    private var fieldLabel: some View {
        if isValid && !text.isEmpty {
            Label(label, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.green)
        } else {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
        }
    }
}