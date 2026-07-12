import SwiftUI

/// A lightweight confetti burst — no external dependencies, pure SwiftUI.
/// Drop it in as an overlay and flip `isActive` to true to fire once.
///
/// Usage:
/// ```swift
/// ZStack {
///     content
///     ConfettiView(isActive: $showConfetti)
/// }
/// ```
struct ConfettiView: View {
    @Binding var isActive: Bool

    private let pieceCount = 60
    private let colors: [Color] = [.bankPrimary, .bankAccent, .bankSuccess, .yellow, .pink, .orange, .purple]

    @State private var pieces: [ConfettiPiece] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiShape(shape: piece.shape)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(x: piece.x, y: piece.y)
                        .opacity(piece.opacity)
                }
            }
            .onChange(of: isActive) { _, active in
                guard active else { return }
                fire(in: geo.size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func fire(in size: CGSize) {
        let originX = size.width / 2
        let originY = size.height * 0.25

        pieces = (0..<pieceCount).map { _ in
            ConfettiPiece(
                x: originX,
                y: originY,
                color: colors.randomElement() ?? .bankPrimary,
                shape: Bool.random() ? .rectangle : .circle,
                size: CGFloat.random(in: 6...11),
                rotation: Double.random(in: 0...360),
                opacity: 1
            )
        }

        for index in pieces.indices {
            let dx = CGFloat.random(in: -140...140)
            let dy = CGFloat.random(in: 220...size.height * 0.7)
            let spin = Double.random(in: 180...720) * (Bool.random() ? 1 : -1)
            let duration = Double.random(in: 0.9...1.6)
            let delay = Double.random(in: 0...0.15)

            withAnimation(.easeOut(duration: duration).delay(delay)) {
                pieces[index].x += dx
                pieces[index].y += dy
                pieces[index].rotation += spin
            }
            withAnimation(.easeIn(duration: 0.4).delay(delay + duration - 0.4)) {
                pieces[index].opacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isActive = false
            pieces = []
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let shape: ConfettiShapeKind
    let size: CGFloat
    var rotation: Double
    var opacity: Double
}

private enum ConfettiShapeKind {
    case rectangle
    case circle
}

nonisolated private struct ConfettiShape: Shape {
    let shape: ConfettiShapeKind

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .circle:
            return Circle().path(in: rect)
        case .rectangle:
            return RoundedRectangle(cornerRadius: 2).path(in: rect)
        }
    }
}

struct ConfettiView_Previews: PreviewProvider {
    struct Harness: View {
        @State private var active = false
        var body: some View {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                Button("Fire") { active = true }
                ConfettiView(isActive: $active)
            }
        }
    }
    static var previews: some View {
        Harness()
    }
}
