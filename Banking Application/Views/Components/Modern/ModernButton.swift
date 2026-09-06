import SwiftUI

struct ModernButton: View {
    enum Variant {
        case filled, outlined, glass, icon, soft
    }

    let title: String
    let systemImage: String?
    let variant: Variant
    let isEnabled: Bool
    /// Overrides the variant's default accent (background tint for `.filled`,
    /// text/border/glass tint for the others). Use this — not an external
    /// `.foregroundStyle()` — to recolor a button, since the label sets its
    /// own foreground internally and would otherwise win over a modifier
    /// applied outside this view (e.g. a red "Sign Out" button).
    let tint: Color?
    let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        variant: Variant = .filled,
        isEnabled: Bool = true,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.isEnabled = isEnabled
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            HapticFeedbackService.shared.lightImpact()
            action()
        }) {
            label
        }
        .buttonStyle(ScalePressButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var label: some View {
        let core = HStack(spacing: AppSpacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
            }
            Text(title)
        }
        .font(.headline)
        .foregroundStyle(foregroundColor)
        .frame(maxWidth: .infinity)
        .frame(minHeight: AppTheme.Control.buttonHeight)
        .padding(.horizontal, AppSpacing.lg)

        switch variant {
        case .filled:
            core
                .background(
                    tint.map { AnyShapeStyle($0.gradient) } ?? AnyShapeStyle(Color.bankPrimaryGradient),
                    in: Capsule(style: .continuous)
                )
                .bankGlowShadow()
        case .outlined:
            core
                .background(Color.clear, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(accentColor.opacity(0.45), lineWidth: 1.5)
                )
        case .glass:
            core.glassControl(cornerRadius: AppTheme.CornerRadius.pill, tint: accentColor)
        case .soft:
            core
                .background(accentColor.opacity(0.12), in: Capsule(style: .continuous))
        case .icon:
            core
                .background(Color.bankCardBackground.opacity(0.85), in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
                )
        }
    }

    /// The variant's brand accent, or `tint` when the caller has overridden it.
    private var accentColor: Color { tint ?? Color.bankPrimary }

    private var foregroundColor: Color {
        switch variant {
        case .filled: return .white
        case .outlined, .glass, .soft: return accentColor
        case .icon: return Color.primary
        }
    }
}

struct ModernIconButton: View {
    let systemImage: String
    var tint: Color = .bankPrimary
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticFeedbackService.shared.lightImpact()
            action()
        }) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: AppTheme.Control.iconButton, height: AppTheme.Control.iconButton)
                .glassControl(cornerRadius: AppTheme.CornerRadius.pill, tint: tint)
        }
        .buttonStyle(ScalePressButtonStyle())
        .accessibilityAddTraits(.isButton)
    }
}

/// Subtle press scale for buttons on touch and pointer devices.
struct ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(AppTheme.Animation.quick, value: configuration.isPressed)
    }
}
