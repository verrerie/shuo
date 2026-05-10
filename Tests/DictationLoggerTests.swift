import XCTest
@testable import Shuo

final class DictationLoggerTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("shuo-log-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    func test_writes_one_line_per_entry() throws {
        let log = DictationLogger(directory: dir, maxBytes: 1_000_000)
        log.log(durationMs: 2410, bytesSent: 120480, language: "fr", result: "ok")
        log.log(durationMs: 850, bytesSent: 42112, language: "zh", result: "err:rate_limit_exceeded")
        log.waitForPendingWrites()

        let path = dir.appendingPathComponent("shuo.log").path
        let body = try String(contentsOfFile: path)
        let lines = body.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("dur_ms=2410 bytes_sent=120480 lang=fr result=ok"))
        XCTAssertTrue(lines[1].contains("dur_ms=850 bytes_sent=42112 lang=zh result=err:rate_limit_exceeded"))
    }

    func test_truncates_when_exceeding_max_bytes() throws {
        let log = DictationLogger(directory: dir, maxBytes: 200)
        for _ in 0..<50 {
            log.log(durationMs: 1000, bytesSent: 50000, language: "en", result: "ok")
        }
        log.waitForPendingWrites()

        let path = dir.appendingPathComponent("shuo.log").path
        let size = (try FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue ?? 0
        XCTAssertLessThanOrEqual(size, 400)
    }
}
