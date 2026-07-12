import SwiftUI

/// Ambient animated background for light **and** dark mode.
/// Soft brand-colored blobs drift and breathe behind content. Uses
/// `TimelineView` so motion stays smooth without stacking multiple
/// `withAnimation` states. Respects Reduce Motion.
struct AnimatedMeshBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 2.0 : 1.0 / 30.0, paused: false)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { canvasContext, size in
                // Base fill
                canvasContext.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(baseColor)
                )

                for blob in Self.blobSpecs {
                    let phase = time / blob.period * (.pi * 2) + blob.phaseOffset
                    let cx = size.width * (blob.anchor.x + cos(phase) * blob.travel.x)
                    let cy = size.height * (blob.anchor.y + sin(phase * blob.yFreq) * blob.travel.y)
                    let scale = 1.0 + 0.08 * sin(phase * 0.7)
                    let radius = blob.baseRadius * scale

                    let rect = CGRect(
                        x: cx - radius,
                        y: cy - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    let color = resolvedColor(for: blob, scheme: colorScheme)
                    canvasContext.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
            .blur(radius: colorScheme == .dark ? 55 : 48)
        }
        .overlay {
            // Soft vertical wash so cards/text stay readable on both themes.
            LinearGradient(
                colors: gradientWash,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var baseColor: Color {
        colorScheme == .dark
            ? Color(red: 0.04, green: 0.05, blue: 0.09)
            : Color(red: 0.94, green: 0.96, blue: 0.99)
    }

    private var gradientWash: [Color] {
        if colorScheme == .dark {
            return [
                Color.bankPrimary.opacity(0.12),
                Color.clear,
                Color.bankSecondary.opacity(0.08)
            ]
        }
        return [
            Color.white.opacity(0.35),
            Color.bankPrimary.opacity(0.06),
            Color.bankSecondary.opacity(0.08)
        ]
    }

    private func resolvedColor(for blob: BlobSpec, scheme: ColorScheme) -> Color {
        let opacity = scheme == .dark ? blob.darkOpacity : blob.lightOpacity
        switch blob.palette {
        case .primary: return Color.bankPrimary.opacity(opacity)
        case .secondary: return Color.bankSecondary.opacity(opacity)
        case .accent: return Color.bankAccent.opacity(opacity)
        case .violet:
            return scheme == .dark
                ? Color(red: 0.45, green: 0.35, blue: 0.95).opacity(opacity)
                : Color(red: 0.55, green: 0.45, blue: 0.98).opacity(opacity)
        case .sky:
            return scheme == .dark
                ? Color(red: 0.15, green: 0.55, blue: 0.85).opacity(opacity)
                : Color(red: 0.45, green: 0.75, blue: 0.98).opacity(opacity)
        }
    }

    private enum Palette { case primary, secondary, accent, violet, sky }

    private struct BlobSpec {
        let palette: Palette
        let baseRadius: CGFloat
        let anchor: CGPoint
        let travel: CGPoint
        let period: Double
        let phaseOffset: Double
        let yFreq: Double
        let lightOpacity: Double
        let darkOpacity: Double
    }

    private static let blobSpecs: [BlobSpec] = [
        BlobSpec(palette: .primary, baseRadius: 180, anchor: CGPoint(x: 0.18, y: 0.12), travel: CGPoint(x: 0.12, y: 0.08), period: 16, phaseOffset: 0.2, yFreq: 1.1, lightOpacity: 0.42, darkOpacity: 0.38),
        BlobSpec(palette: .secondary, baseRadius: 160, anchor: CGPoint(x: 0.82, y: 0.22), travel: CGPoint(x: 0.10, y: 0.10), period: 19, phaseOffset: 1.1, yFreq: 0.9, lightOpacity: 0.36, darkOpacity: 0.32),
        BlobSpec(palette: .violet, baseRadius: 150, anchor: CGPoint(x: 0.55, y: 0.45), travel: CGPoint(x: 0.14, y: 0.12), period: 22, phaseOffset: 2.0, yFreq: 1.3, lightOpacity: 0.28, darkOpacity: 0.30),
        BlobSpec(palette: .accent, baseRadius: 140, anchor: CGPoint(x: 0.22, y: 0.78), travel: CGPoint(x: 0.11, y: 0.09), period: 17, phaseOffset: 0.7, yFreq: 1.0, lightOpacity: 0.30, darkOpacity: 0.26),
        BlobSpec(palette: .sky, baseRadius: 170, anchor: CGPoint(x: 0.78, y: 0.82), travel: CGPoint(x: 0.09, y: 0.11), period: 21, phaseOffset: 2.8, yFreq: 0.85, lightOpacity: 0.34, darkOpacity: 0.28),
        BlobSpec(palette: .primary, baseRadius: 120, anchor: CGPoint(x: 0.48, y: 0.18), travel: CGPoint(x: 0.08, y: 0.06), period: 14, phaseOffset: 3.4, yFreq: 1.2, lightOpacity: 0.22, darkOpacity: 0.24)
    ]
}

extension View {
    /// Places the ambient animated mesh behind this view (whole screens).
    func animatedAppBackground() -> some View {
        self.background { AnimatedMeshBackground() }
    }

    /// Makes navigation / scroll surfaces transparent so the animated
    /// background shows through on tab roots and sheets.
    func transparentChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color.clear)
    }
}
