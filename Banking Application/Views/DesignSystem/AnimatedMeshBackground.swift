import SwiftUI

/// Ambient background: a few radial color wells that drift slowly.
///
/// Drawn in `Canvas` with **radial gradients** (no Gaussian blur pass).
/// The previous implementation blurred a 50pt Canvas every frame at 30 fps,
/// which capped scrolling well below 60. This version targets 60 fps while
/// the scene is active, and pauses when Reduce Motion is on or the app
/// is not in the foreground. It does **not** subscribe to CoreMotion —
/// gyro-driven invalidation of the whole tree is more expensive than the
/// visual payoff on a full-screen wash.
struct AnimatedMeshBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let paused = reduceMotion || scenePhase != .active
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: paused)) { context in
            let time = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { canvasContext, size in
                canvasContext.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(baseColor)
                )

                for blob in Self.blobSpecs {
                    let phase = time / blob.period * (.pi * 2) + blob.phaseOffset
                    let cx = size.width * (blob.anchor.x + cos(phase) * blob.travel.x)
                    let cy = size.height * (blob.anchor.y + sin(phase * blob.yFreq) * blob.travel.y)
                    let radius = blob.baseRadius * (1.0 + 0.06 * sin(phase * 0.7))
                    let rect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
                    let color = resolvedColor(for: blob)
                    canvasContext.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [color, color.opacity(0)]),
                            center: CGPoint(x: cx, y: cy),
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
        }
        .overlay {
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
                Color.bankPrimary.opacity(0.10),
                Color.clear,
                Color.bankSecondary.opacity(0.06)
            ]
        }
        return [
            Color.white.opacity(0.28),
            Color.bankPrimary.opacity(0.05),
            Color.bankSecondary.opacity(0.06)
        ]
    }

    private func resolvedColor(for blob: BlobSpec) -> Color {
        let opacity = colorScheme == .dark ? blob.darkOpacity : blob.lightOpacity
        switch blob.palette {
        case .primary: return Color.bankPrimary.opacity(opacity)
        case .secondary: return Color.bankSecondary.opacity(opacity)
        case .violet:
            return colorScheme == .dark
                ? Color(red: 0.45, green: 0.35, blue: 0.95).opacity(opacity)
                : Color(red: 0.55, green: 0.45, blue: 0.98).opacity(opacity)
        }
    }

    private enum Palette { case primary, secondary, violet }

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
        BlobSpec(palette: .primary, baseRadius: 220, anchor: CGPoint(x: 0.16, y: 0.14), travel: CGPoint(x: 0.08, y: 0.05), period: 18, phaseOffset: 0.2, yFreq: 1.05, lightOpacity: 0.55, darkOpacity: 0.48),
        BlobSpec(palette: .secondary, baseRadius: 200, anchor: CGPoint(x: 0.84, y: 0.22), travel: CGPoint(x: 0.07, y: 0.06), period: 22, phaseOffset: 1.3, yFreq: 0.9, lightOpacity: 0.42, darkOpacity: 0.38),
        BlobSpec(palette: .violet, baseRadius: 240, anchor: CGPoint(x: 0.55, y: 0.78), travel: CGPoint(x: 0.06, y: 0.05), period: 26, phaseOffset: 2.1, yFreq: 1.15, lightOpacity: 0.32, darkOpacity: 0.34)
    ]
}

extension View {
    func animatedAppBackground() -> some View {
        self.background { AnimatedMeshBackground() }
    }

    /// Clear scroll fills so the mesh shows through. Nav/tab chrome is left
    /// to the system so iOS 27 Liquid Glass (and the user slider) apply.
    @ViewBuilder
    func transparentChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.clear)
    }
}
