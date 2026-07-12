import Foundation
import CoreMotion
import SwiftUI
import Combine

/// Publishes smoothed device tilt (roll/pitch) from CoreMotion for use in
/// tilt-reactive UI effects — e.g. the metallic sheen sweeping across a
/// credit card as the phone is tilted, similar to a real card catching
/// light. Values are low-pass filtered so the UI doesn't jitter with every
/// raw sensor sample.
///
/// Single shared instance: multiple cards on screen at once should all
/// react to the same tilt reading rather than each starting their own
/// CMMotionManager (which is expensive and unnecessary).
@MainActor
final class MotionManager: ObservableObject {
    static let shared = MotionManager()

    /// Roll, roughly left/right tilt, in radians. Positive = tilted right.
    @Published private(set) var roll: Double = 0
    /// Pitch, roughly forward/back tilt, in radians. Positive = tilted back.
    @Published private(set) var pitch: Double = 0

    /// Normalized -1...1 convenience values for driving gradient offsets,
    /// rotation angles, and parallax without callers needing to know
    /// radian ranges or clamp values themselves.
    var normalizedX: Double { (roll / Self.maxTiltRadians).clamped(to: -1...1) }
    var normalizedY: Double { (pitch / Self.maxTiltRadians).clamped(to: -1...1) }

    private let motionManager = CMMotionManager()
    private var activeSubscribers = 0
    private static let maxTiltRadians = 0.6  // ~34°, beyond which effects cap out
    private static let smoothing = 0.15       // low-pass filter factor

    private init() {}

    var isAvailable: Bool { motionManager.isDeviceMotionAvailable }

    /// Views call this in `.onAppear` / `.onDisappear` (via the
    /// `.gyroReactive()` modifier below) so CoreMotion only runs while at
    /// least one tilt-reactive view is on screen, and stops as soon as the
    /// last one disappears — keeping battery impact minimal.
    func subscribe() {
        activeSubscribers += 1
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let s = Self.smoothing
            self.roll = self.roll * (1 - s) + motion.attitude.roll * s
            self.pitch = self.pitch * (1 - s) + motion.attitude.pitch * s
        }
    }

    func unsubscribe() {
        activeSubscribers = max(0, activeSubscribers - 1)
        if activeSubscribers == 0 {
            motionManager.stopDeviceMotionUpdates()
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Attaches to any view that wants to read `MotionManager.shared` — starts
/// updates on appear, stops on disappear. Purely a lifecycle helper; the
/// view still reads `@StateObject`/`@ObservedObject` motion values itself.
struct GyroReactiveModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { MotionManager.shared.subscribe() }
            .onDisappear { MotionManager.shared.unsubscribe() }
    }
}

extension View {
    /// Marks this view as consuming device tilt data, tying CoreMotion's
    /// lifecycle to the view's own appearance.
    func gyroReactive() -> some View {
        modifier(GyroReactiveModifier())
    }
}
