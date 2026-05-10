// Tests/RealtimeProtocolTests.swift
import XCTest
@testable import Shuo

final class RealtimeProtocolTests: XCTestCase {

    func test_session_update_uses_ga_shape_and_disables_vad() throws {
        let msg = OutMessage.sessionUpdate(model: "gpt-realtime-whisper", language: .fr)
        let json = try jsonObject(from: msg)
        XCTAssertEqual(json["type"] as? String, "session.update")
        let session = json["session"] as? [String: Any]
        XCTAssertEqual(session?["type"] as? String, "transcription")
        let input = (session?["audio"] as? [String: Any])?["input"] as? [String: Any]
        let format = input?["format"] as? [String: Any]
        XCTAssertEqual(format?["type"] as? String, "audio/pcm")
        XCTAssertEqual(format?["rate"] as? Int, 24000)
        let trans = input?["transcription"] as? [String: Any]
        XCTAssertEqual(trans?["model"] as? String, "gpt-realtime-whisper")
        XCTAssertEqual(trans?["language"] as? String, "fr")
        let nr = input?["noise_reduction"] as? [String: Any]
        XCTAssertEqual(nr?["type"] as? String, "near_field")
        XCTAssertTrue(input?["turn_detection"] is NSNull)
    }

    func test_audio_append_encoding() throws {
        let msg = OutMessage.audioAppend(base64: "AAAA")
        let json = try jsonObject(from: msg)
        XCTAssertEqual(json["type"] as? String, "input_audio_buffer.append")
        XCTAssertEqual(json["audio"] as? String, "AAAA")
    }

    func test_audio_commit_encoding() throws {
        let msg = OutMessage.audioCommit
        let json = try jsonObject(from: msg)
        XCTAssertEqual(json["type"] as? String, "input_audio_buffer.commit")
    }

    func test_decode_completed_event() throws {
        let payload = """
        {"type":"conversation.item.input_audio_transcription.completed","transcript":"bonjour"}
        """.data(using: .utf8)!
        let event = try RealtimeEvent.decode(payload)
        guard case .completed(let text) = event else { return XCTFail("wrong case: \(event)") }
        XCTAssertEqual(text, "bonjour")
    }

    func test_decode_error_event() throws {
        let payload = """
        {"type":"error","error":{"code":"rate_limit_exceeded","message":"slow down"}}
        """.data(using: .utf8)!
        let event = try RealtimeEvent.decode(payload)
        guard case .error(let code, _) = event else { return XCTFail("wrong case: \(event)") }
        XCTAssertEqual(code, "rate_limit_exceeded")
    }

    func test_decode_unknown_event_is_ignored() throws {
        let payload = #"{"type":"some.other.event"}"#.data(using: .utf8)!
        let event = try RealtimeEvent.decode(payload)
        guard case .unknown = event else { return XCTFail("wrong case: \(event)") }
    }

    private func jsonObject(from msg: OutMessage) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: msg.jsonEncoded()) as! [String: Any]
    }
}
