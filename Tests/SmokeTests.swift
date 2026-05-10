// Tests/SmokeTests.swift
import XCTest
@testable import Shuo

final class SmokeTests: XCTestCase {
    func test_module_links() {
        XCTAssertNotNil(AppDelegate())
    }
}
