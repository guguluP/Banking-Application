import SwiftUI

struct CreditCardView: View {
    @Binding var card: Card
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(card.cardType.rawValue)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(cardTypeColor.opacity(0.3))
                    .cornerRadius(4)
                
                Spacer()
                
                Image(systemName: "wave.3.up")
                    .font(.title3)
                    .foregroundColor(.white)
                    .opacity(0.7)
            }
            .padding(.horizontal)
            .padding(.top, AppSpacing.md)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 30)
                    
                    Spacer()
                    
                    Text(card.maskedCardNumber)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .tracking(2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("VALID THRU")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(card.expirationDate)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                
                Text(card.cardHolderName)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.vertical, AppSpacing.lg)
        .frame(height: 180)
        .background(cardBackground)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
    }
    
    private var cardBackground: some View {
        LinearGradient(
            colors: cardGradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var cardGradientColors: [Color] {
        switch card.cardType {
        case .visa: return [Color(red: 0.0, green: 0.48, blue: 1.0), Color(red: 0.2, green: 0.6, blue: 0.9)]
        case .mastercard: return [Color(red: 0.9, green: 0.2, blue: 0.3), Color(red: 1.0, green: 0.5, blue: 0.2)]
        case .amex: return [Color(red: 0.0, green: 0.3, blue: 0.6), Color(red: 0.1, green: 0.5, blue: 0.8)]
        case .discover: return [Color(red: 0.7, green: 0.3, blue: 0.1), Color.red]
        case .debit: return [Color.gray, Color.secondary]
        }
    }
    
    private var cardTypeColor: Color {
        switch card.cardType {
        case .visa: return .blue
        case .mastercard: return .red
        case .amex: return .green
        case .discover: return .orange
        case .debit: return .gray
        }
    }
}