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
            Label(label, systemImage: isValid ? "checkmark.circle.fill" : "")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isValid ? .green : .primary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .padding(12)
                .background(Color(.systemGray6))
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
}