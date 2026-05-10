import XCTest
@testable import Shuo

final class RealtimeClientTests: XCTestCase {

    final class FakeTransport: RealtimeTransport {
        var sentMessages: [Data] = []
        var connectCalled = false
        var closeCalled = false
        var onMessage: ((Data) -> Void)?
        var onClose: ((Int) -> Void)?

        func connect(url: URL, headers: [String: String]) async throws {
            connectCalled = true
        }
        func send(_ data: Data) async throws {
            sentMessages.append(data)
        }
        func close() {
            closeCalled = true
        }
        func deliver(_ data: Data) { onMessage?(data) }
    }

    func test_start_sends_session_update_then_connects() async throws {
        let fake = FakeTransport()
        let client = RealtimeClient(transport: fake, apiKey: "sk-x")
        try await client.start(language: "fr")
        XCTAssertTrue(fake.connectCalled)
        XCTAssertEqual(fake.sentMessages.count, 1)
        let json = try JSONSerialization.jsonObject(with: fake.sentMessages[0]) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "session.update")
    }

    func test_appendAudio_sends_base64_chunk() async throws {
        let fake = FakeTransport()
        let client = RealtimeClient(transport: fake, apiKey: "sk-x")
        try await client.start(language: "en")
        try await client.appendAudio(Data([0, 1, 2, 3]))
        XCTAssertEqual(fake.sentMessages.count, 2)
        let json = try JSONSerialization.jsonObject(with: fake.sentMessages.last!) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "input_audio_buffer.append")
        XCTAssertEqual(json["audio"] as? String, Data([0,1,2,3]).base64EncodedString())
    }

    func test_completed_event_resolves_finish() async throws {
        let fake = FakeTransport()
        let client = RealtimeClient(transport: fake, apiKey: "sk-x")
        try await client.start(language: "en")
        let task = Task { try await client.finishAndAwaitTranscript() }
        try await Task.sleep(nanoseconds: 50_000_000)
        fake.deliver(#"{"type":"conversation.item.input_audio_transcription.completed","transcript":"hello"}"#.data(using: .utf8)!)
        let text = try await task.value
        XCTAssertEqual(text, "hello")
    }

    func test_error_event_throws() async throws {
        let fake = FakeTransport()
        let client = RealtimeClient(transport: fake, apiKey: "sk-x")
        try await client.start(language: "en")
        let task = Task { try await client.finishAndAwaitTranscript() }
        try await Task.sleep(nanoseconds: 50_000_000)
        fake.deliver(#"{"type":"error","error":{"code":"rate_limit_exceeded","message":"slow down"}}"#.data(using: .utf8)!)
        do {
            _ = try await task.value
            XCTFail("expected throw")
        } catch let e as RealtimeError {
            XCTAssertEqual(e.code, "rate_limit_exceeded")
        }
    }
}
