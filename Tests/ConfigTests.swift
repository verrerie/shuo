// Tests/ConfigTests.swift
import XCTest
@testable import Shuo

final class ConfigTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("shuo-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_defaults_when_no_file_exists() throws {
        let store = ConfigStore(directory: tempDir)
        let c = try store.load()
        XCTAssertEqual(c.openaiApiKey, "")
        XCTAssertEqual(c.defaultLanguage, .en)
        XCTAssertEqual(c.hotkeyModifier, .leftOption)
        XCTAssertEqual(c.dailyCapMinutes, 60)
    }

    func test_save_then_load_roundtrip() throws {
        let store = ConfigStore(directory: tempDir)
        var c = try store.load()
        c.openaiApiKey = "sk-test"
        c.defaultLanguage = .fr
        c.dailyCapMinutes = 30
        try store.save(c)

        let reloaded = try ConfigStore(directory: tempDir).load()
        XCTAssertEqual(reloaded.openaiApiKey, "sk-test")
        XCTAssertEqual(reloaded.defaultLanguage, .fr)
        XCTAssertEqual(reloaded.dailyCapMinutes, 30)
    }

    func test_file_has_mode_0600_after_save() throws {
        let store = ConfigStore(directory: tempDir)
        try store.save(try store.load())
        let path = tempDir.appendingPathComponent("config.json").path
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        let perms = attrs[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.int16Value, 0o600)
    }
}
