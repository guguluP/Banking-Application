import SwiftUI

/// Port of "Transitions.dev — Like button". Toggling fills the heart and
/// spring-pops it (scale 1 → 0.82 → 1, matching `t-like-pop`), and fires
/// an 8-dot particle burst flung along independent per-particle vectors —
/// the JS original sets `--px/--py/--pdur/--pdelay` per like for an
/// "organic spray"; this port randomizes the same values on each trigger
/// so the burst never looks mechanically identical twice.
///
/// Usage:
///   LikeButton(isLiked: $viewModel.isLiked)
struct LikeButton: View {
    @Binding var isLiked: Bool
    var tint: Color = Color(red: 0.957, green: 0, blue: 0.318) // #f40051, matches --like-color
    var label: String = "Like"

    @State private var popTrigger = 0
    @State private var burstTrigger = 0
    @State private var particles: [LikeParticle] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            HapticFeedbackService.shared.lightImpact()
            isLiked.toggle()
            if isLiked {
                popTrigger += 1
                if !reduceMotion {
                    fireBurst()
                }
            }
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    heartIcon
                        .keyframeAnimator(initialValue: CGFloat(1), trigger: popTrigger) { view, scale in
                            view.scaleEffect(scale)
                        } keyframes: { _ in
                            CubicKeyframe(0.82, duration: 0.105)
                            CubicKeyframe(1.0, duration: 0.245)
                        }

                    ForEach(particles) { particle in
                        Circle()
                            .fill(tint)
                            .frame(width: particle.size, height: particle.size)
                            .offset(x: particle.currentX, y: particle.currentY)
                            .opacity(particle.opacity)
                    }
                }
                .frame(width: 28, height: 28)

                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLiked ? "Unlike" : "Like")
    }

    private var heartIcon: some View {
        Image(systemName: isLiked ? "heart.fill" : "heart")
            .font(.title2)
            .foregroundStyle(isLiked ? tint : .secondary)
            .animation(.easeInOut(duration: 0.15), value: isLiked)
    }

    /// Spawns 8 particles with randomized vectors/durations/delays/sizes —
    /// the native equivalent of the JS loop that writes CSS custom
    /// properties per dot before adding `.is-bursting`.
    private func fireBurst() {
        let count = 8
        var newParticles: [LikeParticle] = []
        for i in 0..<count {
            let angle = (Double(i) / Double(count)) * 2 * .pi + Double.random(in: -0.2...0.2)
            let distance = CGFloat.random(in: 16...24)
            newParticles.append(
                LikeParticle(
                    targetX: cos(angle) * distance,
                    targetY: sin(angle) * distance,
                    size: CGFloat.random(in: 2...3.5),
                    duration: Double.random(in: 0.5...0.7),
                    delay: Double.random(in: 0...0.05)
                )
            )
        }
        particles = newParticles

        for index in particles.indices {
            let delay = particles[index].delay
            let duration = particles[index].duration
            withAnimation(.easeOut(duration: duration * 0.2).delay(delay)) {
                particles[index].opacity = 1
                particles[index].currentX = particles[index].targetX * 0.25
                particles[index].currentY = particles[index].targetY * 0.25
            }
            withAnimation(.easeOut(duration: duration * 0.8).delay(delay + duration * 0.2)) {
                particles[index].opacity = 0
                particles[index].currentX = particles[index].targetX
                particles[index].currentY = particles[index].targetY
            }
        }

        let totalDuration = (particles.map { $0.duration + $0.delay }.max() ?? 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.1) {
            particles.removeAll()
        }
    }
}

private struct LikeParticle: Identifiable {
    let id = UUID()
    let targetX: CGFloat
    let targetY: CGFloat
    let size: CGFloat
    let duration: Double
    let delay: Double
    var currentX: CGFloat = 0
    var currentY: CGFloat = 0
    var opacity: Double = 0
}

#Preview {
    StatefulPreviewWrapper()
}

private struct StatefulPreviewWrapper: View {
    @State private var isLiked = false
    var body: some View {
        LikeButton(isLiked: $isLiked).padding()
    }
}
