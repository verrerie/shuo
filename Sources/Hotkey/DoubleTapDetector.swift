import Foundation

struct DoubleTapDetector {
    enum Action: Equatable { case start, stop }

    let windowSeconds: TimeInterval
    /// Externally-managed flag indicating whether DictationController is idle.
    /// Set this before invoking onPress so the detector knows whether to emit start vs stop.
    var idleState: Bool = true

    private var lastReleaseAt: TimeInterval? = nil
    private var pressIsHeld: Bool = false

    init(windowSeconds: TimeInterval = 0.4) {
        self.windowSeconds = windowSeconds
    }

    mutating func onPress(at t: TimeInterval) -> Action? {
        guard !pressIsHeld else { return nil }
        pressIsHeld = true

        if idleState {
            if let last = lastReleaseAt, (t - last) < windowSeconds {
                return .start
            }
            return nil
        } else {
            return .stop
        }
    }

    mutating func onRelease(at t: TimeInterval) -> Action? {
        pressIsHeld = false
        lastReleaseAt = t
        return nil
    }
}
