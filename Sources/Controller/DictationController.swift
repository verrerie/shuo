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
    func start(language: String) async throws
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
    private var turnStart: Date?
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

        let lang = language().rawValue
        try await realtime.start(language: lang)
        try audio.start()
        turnStart = Date()
        bytesSent = 0
        state = .listening
        indicator.show(state: .listening)
        onIdleStateChange?(false)
    }

    func stop() async throws {
        os_log("stop entered, state=%{public}@", log: ctrlLog, type: .info, String(describing: state))
        guard state == .listening else {
            os_log("stop bailing — state is not .listening", log: ctrlLog, type: .info)
            return
        }
        state = .finalizing
        indicator.setState(.finalizing)
        audio.stop()
        os_log("audio stopped, awaiting transcript", log: ctrlLog, type: .info)

        do {
            let text = try await realtime.finishAndAwaitTranscript()
            os_log("transcript received, len=%d", log: ctrlLog, type: .info, text.count)
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
        // Sometimes the AVAudioEngine tap fires with a 0-frame buffer at the
        // very start; sending an empty input_audio_buffer.append makes the
        // server reject the whole turn ("Expected base64-encoded audio bytes
        // ... but got empty bytes"). Filter zero-byte chunks here.
        guard !data.isEmpty else { return }
        bytesSent += data.count
        Task { try? await realtime.appendAudio(data) }
    }

    private func logTurn(result: String) {
        let dur = Int((Date().timeIntervalSince(turnStart ?? Date())) * 1000)
        cap.add(seconds: max(0, dur / 1000))
        logger?.log(durationMs: dur, bytesSent: bytesSent, language: language().rawValue, result: result)
    }
}
