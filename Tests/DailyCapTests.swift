import XCTest
@testable import Shuo

final class DailyCapTests: XCTestCase {

    func test_initially_under_cap() {
        let cap = DailyCap(limitMinutes: 60, clock: { Date(timeIntervalSince1970: 0) })
        XCTAssertEqual(cap.state(), .underCap(usedSeconds: 0))
    }

    func test_accumulate_seconds_within_same_day() {
        let cap = DailyCap(limitMinutes: 60, clock: { Date(timeIntervalSince1970: 1_000_000) })
        cap.add(seconds: 120)
        cap.add(seconds: 60)
        if case .underCap(let used) = cap.state() {
            XCTAssertEqual(used, 180)
        } else { XCTFail() }
    }

    func test_warning_at_eighty_percent() {
        let cap = DailyCap(limitMinutes: 1, clock: { Date(timeIntervalSince1970: 0) })
        cap.add(seconds: 50)
        XCTAssertEqual(cap.state(), .warning(usedSeconds: 50))
    }

    func test_blocked_at_or_above_limit() {
        let cap = DailyCap(limitMinutes: 1, clock: { Date(timeIntervalSince1970: 0) })
        cap.add(seconds: 60)
        XCTAssertEqual(cap.state(), .blocked(usedSeconds: 60))
    }

    func test_resets_on_new_local_day() {
        var nowRef = Date(timeIntervalSince1970: 1_700_000_000)
        let cap = DailyCap(limitMinutes: 1, clock: { nowRef })
        cap.add(seconds: 60)
        XCTAssertEqual(cap.state(), .blocked(usedSeconds: 60))

        nowRef = nowRef.addingTimeInterval(25 * 3600)
        XCTAssertEqual(cap.state(), .underCap(usedSeconds: 0))
    }
}
