import SwiftUI
import Combine

struct CreditCardView: View {
    let card: Card
    
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
                    chip
                    
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
        .overlay(specularSheen)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: AppShadows.large.color, radius: AppShadows.large.radius, x: AppShadows.large.x, y: AppShadows.large.y)
    }
    
    /// A faint diagonal band of light simulating how a glossy card catches
    /// light in hand. Deliberately not real glass (`.glassEffect()`) — the
    /// card number and name need full contrast, not translucency, so this
    /// stays a plain gradient overlay instead.
    private var specularSheen: some View {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0), location: 0),
                .init(color: .white.opacity(0.16), location: 0.45),
                .init(color: .white.opacity(0), location: 0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false)
    }
    
    private var chip: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.85), Color(white: 0.6), Color(white: 0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 40, height: 30)
            .overlay(
                VStack(spacing: 3) {
                    ForEach(0..<2, id: \.self) { _ in
                        Rectangle().fill(Color.black.opacity(0.25)).frame(height: 1)
                    }
                }
                .padding(.horizontal, 4)
            )
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
