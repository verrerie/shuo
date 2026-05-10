// Tests/RealtimeProtocolTests.swift
import XCTest
@testable import Shuo

final class RealtimeProtocolTests: XCTestCase {

    func test_session_update_encoding_uses_pcm16_and_no_vad() throws {
        let msg = OutMessage.sessionUpdate(model: "gpt-realtime-whisper", language: "fr")
        let json = try jsonObject(from: msg)
        XCTAssertEqual(json["type"] as? String, "transcription_session.update")
        let session = json["session"] as? [String: Any]
        XCTAssertEqual(session?["input_audio_format"] as? String, "pcm16")
        XCTAssertNil(session?["turn_detection"], "turn_detection should be null/absent")
        let trans = session?["input_audio_transcription"] as? [String: Any]
        XCTAssertEqual(trans?["model"] as? String, "gpt-realtime-whisper")
        XCTAssertEqual(trans?["language"] as? String, "fr")
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
        let data = try msg.jsonEncoded()
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}
