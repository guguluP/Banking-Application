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
            label
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var label: some View {
        let core = HStack(spacing: AppSpacing.sm) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.headline)
        .foregroundColor(foregroundColor)
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.lg)

        switch variant {
        case .filled:
            core
                .background(Color.bankPrimary)
                .cornerRadius(AppTheme.CornerRadius.pill)
        case .outlined:
            core
                .background(Color.clear)
                .cornerRadius(AppTheme.CornerRadius.pill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.pill)
                        .stroke(Color.bankPrimary.opacity(0.3), lineWidth: 1)
                )
        case .glass:
            // Real Liquid Glass on iOS 26+, Material fallback below it.
            core.glassControl(cornerRadius: AppTheme.CornerRadius.pill, tint: Color.bankPrimary)
        case .icon:
            core
                .background(Color(UIColor.systemBackground).opacity(0.7))
                .cornerRadius(AppTheme.CornerRadius.pill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.pill)
                        .stroke(Color.bankPrimary.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .filled: return .white
        case .outlined, .glass: return Color.bankPrimary
        case .icon: return Color.primary
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
                .glassControl(cornerRadius: AppTheme.CornerRadius.pill)
        }
        .buttonStyle(PlainButtonStyle())
    }
}