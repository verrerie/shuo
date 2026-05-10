import Foundation

final class DailyCap {
    enum State: Equatable {
        case underCap(usedSeconds: Int)
        case warning(usedSeconds: Int)
        case blocked(usedSeconds: Int)
    }

    private let limitSeconds: Int
    private let clock: () -> Date
    private var bucketDayStart: Date
    private var usedSeconds: Int = 0

    init(limitMinutes: Int, clock: @escaping () -> Date = Date.init) {
        self.limitSeconds = limitMinutes * 60
        self.clock = clock
        self.bucketDayStart = Calendar.current.startOfDay(for: clock())
    }

    func add(seconds: Int) {
        rollIfNeeded()
        usedSeconds += seconds
    }

    func state() -> State {
        rollIfNeeded()
        if usedSeconds >= limitSeconds { return .blocked(usedSeconds: usedSeconds) }
        if Double(usedSeconds) >= Double(limitSeconds) * 0.8 { return .warning(usedSeconds: usedSeconds) }
        return .underCap(usedSeconds: usedSeconds)
    }

    private func rollIfNeeded() {
        let today = Calendar.current.startOfDay(for: clock())
        if today != bucketDayStart {
            bucketDayStart = today
            usedSeconds = 0
        }
    }
}
