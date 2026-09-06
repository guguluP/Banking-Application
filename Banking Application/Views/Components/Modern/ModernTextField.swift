import SwiftUI

struct ModernTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isValid: Bool = true
    var errorMessage: String = ""
    var systemImage: String?
    var keyboardType: KeyboardTypeHint = .default
    var isSecure: Bool = false

    @FocusState private var isFocused: Bool
    @State private var hasBeenEdited = false

    /// True only once the user has actually interacted with this field. Prevents a fresh,
    /// untouched form from greeting the user with red error states on every field.
    private var showInvalidState: Bool { hasBeenEdited && !isValid }
    private var showError: Bool { showInvalidState && !errorMessage.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isFocused ? Color.bankPrimary : Color.secondary)

            HStack(spacing: 10) {
                if let imageName = systemImage, !isSecure {
                    Image(systemName: imageName)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                }

                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .focused($isFocused)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .sentences)
                .applyKeyboardType(keyboardType)
                .onChange(of: text) { _, _ in hasBeenEdited = true }
                .onChange(of: isFocused) { wasFocused, isFocused in
                    if wasFocused && !isFocused { hasBeenEdited = true }
                }

                if showInvalidState {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.bankDanger)
                        .accessibilityLabel("Invalid input")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.bankGroupedBackground, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isFocused ? 1.5 : 1)
            )
            .animation(AppTheme.Animation.quick, value: isFocused)
            .errorShake(isError: showInvalidState)

            if showError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(errorMessage)
                }
                .font(.caption2)
                .foregroundStyle(Color.bankDanger)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var borderColor: Color {
        if showInvalidState { return .bankDanger }
        if isFocused { return Color.bankPrimary }
        return Color.bankSeparator
    }
}

/// Platform-agnostic keyboard hint mapped to UIKit types only on iOS.
enum KeyboardTypeHint {
    case `default`, numberPad, decimalPad, emailAddress, phonePad
}

private extension View {
    @ViewBuilder
    func applyKeyboardType(_ hint: KeyboardTypeHint) -> some View {
        #if os(iOS)
        switch hint {
        case .default: self.keyboardType(.default)
        case .numberPad: self.keyboardType(.numberPad)
        case .decimalPad: self.keyboardType(.decimalPad)
        case .emailAddress: self.keyboardType(.emailAddress)
        case .phonePad: self.keyboardType(.phonePad)
        }
        #else
        self
        #endif
    }
}
