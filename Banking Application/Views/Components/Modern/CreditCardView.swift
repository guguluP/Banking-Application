import SwiftUI
import Combine

struct CreditCardView: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text(card.cardType.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundColor(networkBadgeForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial.opacity(0.001))
                    .background(Color.black.opacity(0.18))
                    .cornerRadius(4)

                Spacer()

                Image(systemName: "wave.3.up")
                    .font(.title3)
                    .foregroundColor(.white)
                    .opacity(0.75)
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
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VALID THRU")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))

                        Text(card.expirationDate)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }

                    Spacer()

                    networkMark
                }

                Text(card.cardHolderName.uppercased())
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .tracking(0.5)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical, AppSpacing.lg)
        .frame(height: 190)
        .background(metallicBackground)
        .overlay(brushedMetalTexture)
        .overlay(specularSheen)
        .overlay(edgeHighlight)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: AppShadows.large.color, radius: AppShadows.large.radius, x: AppShadows.large.x, y: AppShadows.large.y)
    }

    // MARK: - Metallic surface

    /// Multi-stop metallic gradient per network. Real metal reads as several
    /// bands of light/dark rather than a single two-color blend, so each
    /// network uses 4-5 stops moving diagonally across the card.
    private var metallicBackground: some View {
        LinearGradient(
            stops: cardGradientStops,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Very fine diagonal hairlines simulating a brushed-metal finish.
    /// Kept extremely subtle (low opacity) so it reads as texture, not noise.
    private var brushedMetalTexture: some View {
        Canvas { context, size in
            let lineSpacing: CGFloat = 3
            var x: CGFloat = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(path, with: .color(.white.opacity(0.035)), lineWidth: 1)
                x += lineSpacing
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }

    /// A soft, wide band of light simulating how a metallic card catches
    /// light when tilted. Deliberately not real glass — the card number and
    /// name need full contrast, not translucency.
    private var specularSheen: some View {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0), location: 0),
                .init(color: .white.opacity(0.22), location: 0.42),
                .init(color: .white.opacity(0.05), location: 0.5),
                .init(color: .white.opacity(0), location: 0.62)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false)
    }

    /// Faint top edge highlight + bottom edge shadow — reinforces the sense
    /// of a rigid, slightly convex metal card rather than a flat sticker.
    private var edgeHighlight: some View {
        VStack {
            LinearGradient(
                colors: [.white.opacity(0.35), .white.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 10)

            Spacer()

            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 14)
        }
        .allowsHitTesting(false)
    }

    private var chip: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.92), Color(white: 0.68), Color(white: 0.88)],
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
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            )
    }

    // MARK: - Network branding

    @ViewBuilder
    private var networkMark: some View {
        switch card.cardType {
        case .visa:
            Text("VISA")
                .font(.title3.weight(.heavy))
                .italic()
                .foregroundColor(.white)
                .tracking(1)

        case .mastercard:
            HStack(spacing: -14) {
                Circle()
                    .fill(Color(red: 0.92, green: 0.34, blue: 0.2))
                    .frame(width: 28, height: 28)
                Circle()
                    .fill(Color(red: 0.98, green: 0.65, blue: 0.15))
                    .frame(width: 28, height: 28)
                    .blendMode(.plusLighter)
            }
            .compositingGroup()
            .opacity(0.95)

        case .rupay:
            HStack(spacing: 2) {
                Text("Ru")
                    .font(.title3.weight(.heavy))
                    .foregroundColor(.white)
                Text("Pay")
                    .font(.title3.weight(.heavy))
                    .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.15))
            }

        case .amex:
            Text("AMEX")
                .font(.subheadline.weight(.heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.18))
                .cornerRadius(3)

        case .discover:
            Text("DISCOVER")
                .font(.caption.weight(.heavy))
                .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.2))
                .tracking(0.5)

        case .debit:
            Text("DEBIT")
                .font(.caption.weight(.heavy))
                .foregroundColor(.white.opacity(0.85))
                .tracking(1)
        }
    }

    private var networkBadgeForeground: Color {
        card.cardType == .discover ? Color(red: 1.0, green: 0.65, blue: 0.2) : .white
    }

    /// Layered metallic stops per network — chosen to echo each brand's real
    /// card-stock finish (Visa platinum-blue, Mastercard warm titanium,
    /// RuPay brushed gold/navy, Amex gunmetal, Discover copper, Debit silver).
    private var cardGradientStops: [Gradient.Stop] {
        switch card.cardType {
        case .visa:
            return [
                .init(color: Color(red: 0.07, green: 0.13, blue: 0.32), location: 0.0),
                .init(color: Color(red: 0.10, green: 0.22, blue: 0.52), location: 0.35),
                .init(color: Color(red: 0.16, green: 0.38, blue: 0.72), location: 0.65),
                .init(color: Color(red: 0.06, green: 0.16, blue: 0.38), location: 1.0)
            ]
        case .mastercard:
            return [
                .init(color: Color(red: 0.20, green: 0.16, blue: 0.16), location: 0.0),
                .init(color: Color(red: 0.34, green: 0.24, blue: 0.20), location: 0.4),
                .init(color: Color(red: 0.44, green: 0.30, blue: 0.20), location: 0.62),
                .init(color: Color(red: 0.18, green: 0.14, blue: 0.14), location: 1.0)
            ]
        case .rupay:
            return [
                .init(color: Color(red: 0.05, green: 0.10, blue: 0.24), location: 0.0),
                .init(color: Color(red: 0.10, green: 0.18, blue: 0.36), location: 0.32),
                .init(color: Color(red: 0.55, green: 0.42, blue: 0.14), location: 0.58),
                .init(color: Color(red: 0.30, green: 0.24, blue: 0.10), location: 0.78),
                .init(color: Color(red: 0.06, green: 0.11, blue: 0.24), location: 1.0)
            ]
        case .amex:
            return [
                .init(color: Color(red: 0.10, green: 0.16, blue: 0.22), location: 0.0),
                .init(color: Color(red: 0.20, green: 0.30, blue: 0.38), location: 0.4),
                .init(color: Color(red: 0.28, green: 0.40, blue: 0.48), location: 0.65),
                .init(color: Color(red: 0.09, green: 0.15, blue: 0.20), location: 1.0)
            ]
        case .discover:
            return [
                .init(color: Color(red: 0.24, green: 0.11, blue: 0.05), location: 0.0),
                .init(color: Color(red: 0.46, green: 0.20, blue: 0.06), location: 0.4),
                .init(color: Color(red: 0.68, green: 0.34, blue: 0.08), location: 0.65),
                .init(color: Color(red: 0.20, green: 0.09, blue: 0.04), location: 1.0)
            ]
        case .debit:
            return [
                .init(color: Color(red: 0.24, green: 0.25, blue: 0.27), location: 0.0),
                .init(color: Color(red: 0.42, green: 0.43, blue: 0.46), location: 0.4),
                .init(color: Color(red: 0.55, green: 0.56, blue: 0.59), location: 0.62),
                .init(color: Color(red: 0.22, green: 0.23, blue: 0.25), location: 1.0)
            ]
        }
    }
}

private extension CardType {
    /// Short label for the top-left network badge; RuPay and Amex use
    /// shorter forms than their raw enum value so the badge stays compact.
    var displayName: String {
        switch self {
        case .amex: return "Amex"
        default: return rawValue
        }
    }
}
