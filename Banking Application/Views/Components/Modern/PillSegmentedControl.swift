import SwiftUI

struct PillSegmentedControl<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String {
    @Binding var selection: T
    let items: [T]
    var icon: ((T) -> String)? = nil
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button(action: {
                    withAnimation(AppTheme.Animation.standard) {
                        selection = item
                    }
                    HapticFeedbackService.shared.lightImpact()
                }) {
                    HStack(spacing: 6) {
                        if let icon = icon?(item) {
                            Image(systemName: icon)
                                .font(.subheadline.weight(.semibold))
                        }
                        Text(item.rawValue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected(item) ? .white : .primary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .background {
                        if isSelected(item) {
                            Capsule(style: .continuous)
                                .fill(Color.bankPrimaryGradient)
                                .matchedGeometryEffect(id: "selectedSegment", in: namespace)
                                .shadow(color: Color.bankPrimary.opacity(0.28), radius: 8, x: 0, y: 3)
                        }
                    }
                }
                .buttonStyle(ScalePressButtonStyle())
                .accessibilityAddTraits(isSelected(item) ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(5)
        .background(Color.bankGroupedBackground.opacity(0.9), in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.bankSeparator, lineWidth: 1)
        )
    }

    private func isSelected(_ item: T) -> Bool {
        selection == item
    }
}
