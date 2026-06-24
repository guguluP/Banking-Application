import SwiftUI

struct ModernButton: View {
    enum Variant {
        case filled, outlined, glass, icon
    }
    
    let title: String
    let systemImage: String?
    let variant: Variant
    let action: () -> Void
    
    init(title: String, systemImage: String? = nil, variant: Variant = .filled, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackService.shared.lightImpact()
            action()
        }) {
            HStack(spacing: AppSpacing.sm) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .foregroundColor(foregroundColor)
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.lg)
            .background(backgroundColor)
            .cornerRadius(AppTheme.CornerRadius.pill)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.pill)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .filled: return .white
        case .outlined, .glass: return Color.bankPrimary
        case .icon: return Color.primary
        }
    }
    
    private var backgroundColor: some View {
        switch variant {
        case .filled:
            return Color.bankPrimary
        case .outlined:
            return Color.clear
        case .glass:
            return Color.glassBackground
        case .icon:
            return Color(UIColor.systemBackground).opacity(0.7)
        }
    }
    
    private var borderColor: Color {
        switch variant {
        case .filled: return .clear
        case .outlined, .glass, .icon: return Color.bankPrimary.opacity(0.3)
        }
    }
}

struct ModernIconButton: View {
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedbackService.shared.lightImpact()
            action()
        }) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(Color.bankPrimary)
                .frame(width: 44, height: 44)
                .background(Color.glassBackground)
                .cornerRadius(AppTheme.CornerRadius.pill)
        }
        .buttonStyle(PlainButtonStyle())
    }
}