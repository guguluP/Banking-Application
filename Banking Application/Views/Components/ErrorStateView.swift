import SwiftUI

// Full-screen error overlay
struct FullScreenErrorView: View {
    let error: AppError
    let action: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            
            GlassCard {
                VStack(spacing: AppSpacing.xl) {
                    Image(systemName: error.icon)
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    VStack(spacing: AppSpacing.sm) {
                        Text(error.title)
                            .font(.headline)
                        
                        Text(error.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    if let suggestion = error.suggestion {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(AppTheme.CornerRadius.small)
                    }
                    
                    ModernButton(
                        title: error.actionTitle,
                        variant: .filled
                    ) {
                        action()
                    }
                    
                    ModernButton(
                        title: "Dismiss",
                        variant: .glass
                    ) {
                        dismiss()
                    }
                }
                .padding()
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    FullScreenErrorView(error: .invalidAmount, action: {})
}
