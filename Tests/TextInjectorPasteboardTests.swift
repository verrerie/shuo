import XCTest
import AppKit
@testable import Shuo

final class TextInjectorPasteboardTests: XCTestCase {

    func test_string_snapshot_restore_round_trip() {
        let pb = NSPasteboard(name: NSPasteboard.Name(rawValue: "shuo.tests.\(UUID().uuidString)"))
        pb.clearContents()
        pb.setString("original", forType: .string)

        let snap = TextInjector.snapshot(of: pb)

        pb.clearContents()
        pb.setString("transcribed", forType: .string)
        XCTAssertEqual(pb.string(forType: .string), "transcribed")

        TextInjector.restore(snap, to: pb)
        XCTAssertEqual(pb.string(forType: .string), "original")
    }

    func test_multitype_snapshot_restore() {
        let pb = NSPasteboard(name: NSPasteboard.Name(rawValue: "shuo.tests.\(UUID().uuidString)"))
        pb.clearContents()
        pb.setString("text", forType: .string)
        pb.setData("rtf-bytes".data(using: .utf8), forType: .rtf)

        let snap = TextInjector.snapshot(of: pb)
        pb.clearContents()
        pb.setString("clobbered", forType: .string)
        TextInjector.restore(snap, to: pb)

        XCTAssertEqual(pb.string(forType: .string), "text")
        XCTAssertEqual(pb.data(forType: .rtf), "rtf-bytes".data(using: .utf8))
    }
}
