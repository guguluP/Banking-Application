import Foundation
import CoreMotion
import Observation

/// Publishes smoothed device tilt from CoreMotion for use in
/// tilt-reactive UI effects — e.g. the metallic sheen sweeping across a
/// credit card as the phone is tilted, similar to a real card catching
/// light. Values are low-pass filtered so the UI doesn't jitter with every
/// raw sensor sample.
///
/// Single shared instance: multiple cards on screen at once should all
/// react to the same tilt reading rather than each starting their own
/// CMMotionManager (which is expensive and unnecessary).
@MainActor
@Observable
final class MotionManager {
    static let shared = MotionManager()

    /// Device tilt normalized to -1...1 on each axis, for driving gradient
    /// offsets and rotation angles without callers knowing radian ranges.
    struct Tilt: Equatable {
        /// Left/right (from roll). Positive = tilted right.
        var x: Double
        /// Forward/back (from pitch). Positive = tilted back.
        var y: Double

        static let zero = Tilt(x: 0, y: 0)
    }

    /// The one value views observe. Only republished when it moves by more
    /// than `deadBand`, so sensor noise at 60 Hz does not re-render the UI.
    private(set) var tilt: Tilt = .zero

    var normalizedX: Double { tilt.x }
    var normalizedY: Double { tilt.y }

    /// Smoothed raw readings in radians. Not observed; they change every sample.
    @ObservationIgnored private var roll: Double = 0
    @ObservationIgnored private var pitch: Double = 0
    @ObservationIgnored private let motionManager = CMMotionManager()
    @ObservationIgnored private var activeSubscribers = 0
    private static let maxTiltRadians = 0.6  // ~34°, beyond which effects cap out
    private static let smoothing = 0.15       // low-pass filter factor
    private static let deadBand = 0.01        // in normalized units (~0.3°)

    private init() {}

    var isAvailable: Bool { motionManager.isDeviceMotionAvailable }

    /// Views call this in `.onAppear` / `.onDisappear` so CoreMotion only
    /// runs while at least one tilt-reactive view is on screen, and stops as
    /// soon as the last one disappears, keeping battery impact minimal.
    func subscribe() {
        activeSubscribers += 1
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let s = Self.smoothing
            self.roll = self.roll * (1 - s) + motion.attitude.roll * s
            self.pitch = self.pitch * (1 - s) + motion.attitude.pitch * s
            self.publishIfMoved()
        }
    }

    func unsubscribe() {
        activeSubscribers = max(0, activeSubscribers - 1)
        if activeSubscribers == 0 {
            motionManager.stopDeviceMotionUpdates()
        }
    }

    private func publishIfMoved() {
        let next = Tilt(
            x: (roll / Self.maxTiltRadians).clamped(to: -1...1),
            y: (pitch / Self.maxTiltRadians).clamped(to: -1...1)
        )
        guard abs(next.x - tilt.x) > Self.deadBand || abs(next.y - tilt.y) > Self.deadBand else { return }
        tilt = next
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
