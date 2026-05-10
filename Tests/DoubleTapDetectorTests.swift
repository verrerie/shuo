// Tests/DoubleTapDetectorTests.swift
import XCTest
@testable import Shuo

final class DoubleTapDetectorTests: XCTestCase {

    func test_single_press_does_not_start() {
        var d = DoubleTapDetector(windowSeconds: 0.4)
        d.idleState = true
        XCTAssertNil(d.onPress(at: 0.0))
        XCTAssertNil(d.onRelease(at: 0.05))
    }

    func test_double_press_within_window_starts() {
        var d = DoubleTapDetector(windowSeconds: 0.4)
        d.idleState = true
        XCTAssertNil(d.onPress(at: 0.0))
        XCTAssertNil(d.onRelease(at: 0.05))
        XCTAssertEqual(d.onPress(at: 0.30), .start)
    }

    func test_double_press_outside_window_does_not_start() {
        var d = DoubleTapDetector(windowSeconds: 0.4)
        d.idleState = true
        _ = d.onPress(at: 0.0)
        _ = d.onRelease(at: 0.05)
        XCTAssertNil(d.onPress(at: 0.50))
    }

    func test_window_edge_inclusive_below_exclusive_above() {
        var d = DoubleTapDetector(windowSeconds: 0.4)
        d.idleState = true
        _ = d.onPress(at: 0.0)
        _ = d.onRelease(at: 0.0)
        XCTAssertEqual(d.onPress(at: 0.399), .start)

        var d2 = DoubleTapDetector(windowSeconds: 0.4)
        d2.idleState = true
        _ = d2.onPress(at: 0.0)
        _ = d2.onRelease(at: 0.0)
        XCTAssertNil(d2.onPress(at: 0.401))
    }

    func test_single_press_while_listening_stops() {
        var d = DoubleTapDetector(windowSeconds: 0.4)
        d.idleState = false   // currently listening
        XCTAssertEqual(d.onPress(at: 1.0), .stop)
    }

    func test_modifier_held_then_released_does_not_loop() {
        // a long hold without a release in between presses must not produce repeated starts
        var d = DoubleTapDetector(windowSeconds: 0.4)
        d.idleState = true
        XCTAssertNil(d.onPress(at: 0.0))
        // no release event, then another spurious press 100 ms later
        XCTAssertNil(d.onPress(at: 0.1))
    }
}
