import SwiftUI

struct BillerPicker: View {
    @Binding var selection: Biller?
    let billers: [Biller]
    
    var body: some View {
        Menu {
            ForEach(billers) { biller in
                Button(action: { selection = biller }) {
                    Text(biller.displayName)
                        .font(.subheadline)
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let biller = selection {
                        Text(biller.displayName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    } else {
                        Text("Select Biller")
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
            .cornerRadius(AppTheme.CornerRadius.small)
        }
        .accessibilityLabel(selection == nil ? "Select Biller" : selection?.displayName ?? "")
    }
}