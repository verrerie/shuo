import XCTest
import Foundation
@testable import Shuo

final class DictationStateMachineTests: XCTestCase {

    final class FakeAudio: AudioCaptureProtocol {
        var started = false; var stopped = false
        var onChunk: ((Data) -> Void)?
        var onError: ((Error) -> Void)?
        func start() throws { started = true }
        func stop() { stopped = true }
    }

    final class FakeRealtime: RealtimeClientProtocol {
        var startedLanguage: Language?
        var appended: [Data] = []
        var finishCalled = false
        var cancelCalled = false
        var transcript: String = "result"
        func start(language: Language) async throws { startedLanguage = language }
        func appendAudio(_ pcm16: Data) async throws { appended.append(pcm16) }
        func finishAndAwaitTranscript() async throws -> String { finishCalled = true; return transcript }
        func cancel() { cancelCalled = true }
    }

    final class FakePaste: TextInjectorProtocol {
        var pasted: String?
        func paste(_ text: String) { pasted = text }
    }

    final class FakeIndicator: IndicatorProtocol {
        var state: IndicatorState? = nil
        var visible = false
        func show(state: IndicatorState) { self.state = state; visible = true }
        func setState(_ s: IndicatorState) { state = s }
        func hide() { visible = false }
    }

    func test_happy_path_records_transcribes_and_pastes() async throws {
        let audio = FakeAudio(); let rt = FakeRealtime(); let paste = FakePaste(); let ind = FakeIndicator()
        let cap = DailyCap(limitMinutes: 60)
        let ctrl = DictationController(audio: audio, realtime: rt, paste: paste, indicator: ind,
                                       cap: cap, language: { .fr }, logger: nil)

        try await ctrl.start()
        XCTAssertTrue(audio.started); XCTAssertEqual(rt.startedLanguage, .fr); XCTAssertEqual(ind.state, .listening)

        audio.onChunk?(Data([0,1,2,3]))
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(rt.appended.count, 1)

        try await ctrl.stop()
        XCTAssertTrue(audio.stopped); XCTAssertTrue(rt.finishCalled)
        XCTAssertEqual(paste.pasted, "result")
        XCTAssertFalse(ind.visible)
    }

    func test_blocked_by_cap_does_not_start() async throws {
        let audio = FakeAudio(); let rt = FakeRealtime(); let paste = FakePaste(); let ind = FakeIndicator()
        let cap = DailyCap(limitMinutes: 1)
        cap.add(seconds: 60)
        let ctrl = DictationController(audio: audio, realtime: rt, paste: paste, indicator: ind,
                                       cap: cap, language: { .en }, logger: nil)

        do { try await ctrl.start(); XCTFail("expected throw") }
        catch let e as DictationError { XCTAssertEqual(e, .blockedByDailyCap) }
        XCTAssertFalse(audio.started)
    }

    func test_empty_transcript_does_not_paste() async throws {
        let audio = FakeAudio(); let rt = FakeRealtime(); let paste = FakePaste(); let ind = FakeIndicator()
        rt.transcript = "   "
        let ctrl = DictationController(audio: audio, realtime: rt, paste: paste, indicator: ind,
                                       cap: DailyCap(limitMinutes: 60), language: { .en }, logger: nil)
        try await ctrl.start()
        try await ctrl.stop()
        XCTAssertNil(paste.pasted)
    }
}

extension IndicatorState: Equatable {}
