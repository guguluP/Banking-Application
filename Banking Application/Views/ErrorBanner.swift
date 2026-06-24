import SwiftUI

enum PaymentError: String {
    case insufficientBalance = "Insufficient Balance"
    case sameAccount = "Same Account"
    case invalidAmount = "Invalid Amount"
    case invalidUPI = "Invalid UPI ID"
    case authenticationFailed = "Authentication Failed"
    
    var description: String {
        switch self {
        case .insufficientBalance: return "Check your account balance"
        case .sameAccount: return "Select different accounts"
        case .invalidAmount: return "Enter a valid positive amount"
        case .invalidUPI: return "Use format: name@upi"
        case .authenticationFailed: return "Enable Face ID or try again"
        }
    }
    
    var imageName: String {
        switch self {
        case .insufficientBalance, .invalidAmount, .invalidUPI, .sameAccount: return "exclamationmark.triangle.fill"
        case .authenticationFailed: return "faceid"
        }
    }
}

struct ErrorBanner: View {
    let error: PaymentError
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.imageName)
                .foregroundColor(.orange)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(error.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(error.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityLabel("\(error.rawValue): \(error.description)")
    }
}

struct ErrorBannerView: View {
    let error: AppError
    var onRetry: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: error.icon)
                .foregroundColor(.orange)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if onRetry != nil {
                Button(action: {
                    HapticFeedbackService.shared.lightImpact()
                    onRetry?()
                }) {
                    Text(error.actionTitle)
                        .font(.caption.weight(.medium))
                        .foregroundColor(Color.bankPrimary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(AppTheme.CornerRadius.small)
    }
}

struct ErrorBannerModern: View {
    let error: AppError
    var onRetry: (() -> Void)? = nil
    
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: error.icon)
                .font(.title3)
                .foregroundColor(errorColor)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let suggestion = error.suggestion {
                    Text(suggestion)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if onRetry != nil {
                Button(action: {
                    HapticFeedbackService.shared.lightImpact()
                    onRetry?()
                }) {
                    Text(error.actionTitle)
                        .font(.caption.weight(.medium))
                        .foregroundColor(Color.bankPrimary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(AppTheme.CornerRadius.small)
        .shadow(color: AppShadows.small.color, radius: AppShadows.small.radius, x: AppShadows.small.x, y: AppShadows.small.y)
        .offset(y: animate ? 0 : -20)
        .opacity(animate ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animate = true
            }
        }
    }
    
    private var errorColor: Color {
        switch error {
        case .networkError: return .orange
        case .insufficientFunds: return .red
        case .biometricFailed: return .blue
        case .authenticationFailed: return .red
        default: return .orange
        }
    }
}

struct SuccessBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
                .symbolRenderingMode(.hierarchical)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(AppTheme.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ErrorStateView: View {
    let imageName: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        GlassCard {
            VStack(spacing: AppSpacing.md) {
                Image(systemName: imageName)
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                ModernButton(
                    title: actionTitle,
                    variant: .filled
                ) {
                    action()
                }
                .padding(.horizontal, 24)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}