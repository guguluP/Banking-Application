import SwiftUI

struct ModernTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isValid: Bool = true
    var errorMessage: String = ""
    var systemImage: String?
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    
    @FocusState private var isFocused: Bool
    private var showError: Bool { !errorMessage.isEmpty && !isValid }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(isFocused ? Color.bankPrimary : Color.primary)
            
            HStack(spacing: 8) {
                if let imageName = systemImage, !isSecure {
                    Image(systemName: imageName)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }
                
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .focused($isFocused)
                }
                
                if !isValid {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemGroupedBackground))
            .cornerRadius(AppTheme.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                    .stroke(borderColor, lineWidth: 1)
            )
            
            if showError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(errorMessage)
                }
                .font(.caption2)
                .foregroundColor(.red)
            }
        }
    }
    
    private var borderColor: Color {
        if !isValid { return .red }
        if isFocused { return Color.bankPrimary }
        return Color.secondary.opacity(0.3)
    }
}