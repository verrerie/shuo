import Foundation
import os.log

private let ctrlLog = OSLog(subsystem: "app.shuo", category: "controller")

protocol AudioCaptureProtocol: AnyObject {
    var onChunk: ((Data) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
    func start() throws
    func stop()
}

protocol RealtimeClientProtocol: AnyObject {
    func start(language: Language) async throws
    func appendAudio(_ pcm16: Data) async throws
    func finishAndAwaitTranscript() async throws -> String
    func cancel()
}

protocol TextInjectorProtocol {
    func paste(_ text: String)
}

protocol IndicatorProtocol: AnyObject {
    func show(state: IndicatorState)
    func setState(_ state: IndicatorState)
    func hide()
}

extension AudioCapture: AudioCaptureProtocol {}
extension RealtimeClient: RealtimeClientProtocol {}
extension IndicatorWindow: IndicatorProtocol {}

struct LiveTextInjector: TextInjectorProtocol {
    func paste(_ text: String) { TextInjector.paste(text) }
}

enum DictationError: Error, Equatable {
    case blockedByDailyCap
    case alreadyRunning
    case noApiKey
}

final class DictationController {
    enum State { case idle, listening, finalizing }

    private let audio: AudioCaptureProtocol
    private let realtime: RealtimeClientProtocol
    private let paste: TextInjectorProtocol
    private let indicator: IndicatorProtocol
    private let cap: DailyCap
    private let language: () -> Language
    private let logger: DictationLogger?

    private(set) var state: State = .idle
    /// nil between turns; set when a turn enters .listening.
    private(set) var turnStartedAt: Date?
    private var bytesSent: Int = 0

    var onIdleStateChange: ((Bool) -> Void)?

    init(audio: AudioCaptureProtocol,
         realtime: RealtimeClientProtocol,
         paste: TextInjectorProtocol,
         indicator: IndicatorProtocol,
         cap: DailyCap,
         language: @escaping () -> Language,
         logger: DictationLogger?) {
        self.audio = audio
        self.realtime = realtime
        self.paste = paste
        self.indicator = indicator
        self.cap = cap
        self.language = language
        self.logger = logger
        self.audio.onChunk = { [weak self] data in self?.handleChunk(data) }
    }

    func start() async throws {
        guard state == .idle else { throw DictationError.alreadyRunning }
        if case .blocked = cap.state() { throw DictationError.blockedByDailyCap }

        try await realtime.start(language: language())
        try audio.start()
        turnStartedAt = Date()
        bytesSent = 0
        state = .listening
        indicator.show(state: .listening)
        onIdleStateChange?(false)
    }

    func stop() async throws {
        guard state == .listening else { return }
        state = .finalizing
        indicator.setState(.finalizing)
        audio.stop()

        do {
            let text = try await realtime.finishAndAwaitTranscript()
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { paste.paste(trimmed) }
            logTurn(result: trimmed.isEmpty ? "ok:empty" : "ok")
        } catch let e as RealtimeError {
            os_log("realtime error during stop: %{public}@", log: ctrlLog, type: .error, e.code)
            logTurn(result: "err:\(e.code)")
        } catch {
            os_log("unknown error during stop: %{public}@", log: ctrlLog, type: .error, String(describing: error))
            logTurn(result: "err:unknown")
        }

        finalize()
    }

    func cancel() {
        if state == .idle { return }
        audio.stop()
        realtime.cancel()
        logTurn(result: "cancelled")
        finalize()
    }

    private func finalize() {
        indicator.hide()
        state = .idle
        onIdleStateChange?(true)
    }

    private func handleChunk(_ data: Data) {
        // Skip empty buffers — the server rejects empty input_audio_buffer.append
        // with "Expected base64-encoded audio bytes ... but got empty bytes",
        // and the AVAudioEngine tap can fire one at the very start of a turn.
        guard !data.isEmpty else { return }
        bytesSent += data.count
        Task { try? await realtime.appendAudio(data) }
    }

    private func logTurn(result: String) {
        let dur = Int((Date().timeIntervalSince(turnStartedAt ?? Date())) * 1000)
        cap.add(seconds: max(0, dur / 1000))
        logger?.log(durationMs: dur, bytesSent: bytesSent, language: language(), result: result)
    }
}
