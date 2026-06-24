import SwiftUI

struct PillSegmentedControl<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String {
    @Binding var selection: T
    let items: [T]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = item
                        HapticFeedbackService.shared.lightImpact()
                    }
                }) {
                    Text(item.rawValue)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isSelected(item) ? .white : .primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(AppTheme.CornerRadius.pill)
    }
    
    private func isSelected(_ item: T) -> Bool {
        selection == item
    }
}