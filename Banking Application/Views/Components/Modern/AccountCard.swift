import SwiftUI

struct AccountCard: View {
    let account: Account
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedbackService.shared.lightImpact()
            action()
        }) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.accountType.rawValue)
                                .font(.caption)
                                .textCase(.uppercase)
                                .foregroundColor(.secondary)
                            
                            Text(account.nickname ?? "Account")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: accountStatusIcon)
                            .foregroundColor(accountStatusColor)
                    }
                    
                    Text(account.formattedBalance)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("Available: \(account.formattedAvailableBalance)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("•••• \(account.accountNumber.suffix(4))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var accountStatusIcon: String {
        account.accountStatus == .active ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    private var accountStatusColor: Color {
        account.accountStatus == .active ? .green : .gray
    }
}