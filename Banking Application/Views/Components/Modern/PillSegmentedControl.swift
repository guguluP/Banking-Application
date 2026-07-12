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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = item
                    }
                    HapticFeedbackService.shared.lightImpact()
                }) {
                    HStack(spacing: 4) {
                        if let icon = icon?(item) {
                            Image(systemName: icon)
                        }
                        Text(item.rawValue)
                    }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isSelected(item) ? .white : .primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isSelected(item) {
                                // Real Liquid Glass on iOS 26+, tinted with the
                                // brand color; Material fallback below that.
                                Color.clear
                                    .glassControl(cornerRadius: AppTheme.CornerRadius.pill, tint: Color.bankPrimary)
                                    .matchedGeometryEffect(id: "selectedSegment", in: namespace)
                            }
                        }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(Color(UIColor.systemGroupedBackground))
        .clipShape(Capsule())
    }
    
    private func isSelected(_ item: T) -> Bool {
        selection == item
    }
}