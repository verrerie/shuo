import Foundation
import os.log

private let log = OSLog(subsystem: "app.shuo", category: "realtime")

protocol RealtimeTransport: AnyObject {
    var onMessage: ((Data) -> Void)? { get set }
    var onClose: ((Int) -> Void)? { get set }
    func connect(url: URL, headers: [String: String]) async throws
    func send(_ data: Data) async throws
    func close()
}

struct RealtimeError: Error, Equatable {
    let code: String
    let message: String
}

final class RealtimeClient {
    private let transport: RealtimeTransport
    private let apiKey: String
    private let url = URL(string: "wss://api.openai.com/v1/realtime?intent=transcription")!
    private let model = "gpt-realtime-whisper"

    private var pendingTranscript: CheckedContinuation<String, Error>?
    private var earlyError: RealtimeError?

    init(transport: RealtimeTransport, apiKey: String) {
        self.transport = transport
        self.apiKey = apiKey
        transport.onMessage = { [weak self] data in self?.handleIncoming(data) }
        transport.onClose = { [weak self] code in self?.handleClose(code: code) }
    }

    func start(language: Language) async throws {
        // Reset per-turn state. The previous turn's normal-closure causes
        // handleClose to populate earlyError; without this reset, the next
        // turn's finishAndAwaitTranscript would throw the stale error
        // before ever sending commit.
        earlyError = nil
        pendingTranscript = nil

        // GA Realtime API: do NOT send OpenAI-Beta. The realtime=v1 header
        // pins us to the legacy beta endpoint, which doesn't have
        // gpt-realtime-whisper.
        try await transport.connect(url: url, headers: [
            "Authorization": "Bearer \(apiKey)"
        ])
        let payload = OutMessage.sessionUpdate(model: model, language: language).jsonEncoded()
        if log.isEnabled(type: .info), let s = String(data: payload, encoding: .utf8) {
            os_log("send %{public}@", log: log, type: .info, s)
        }
        try await transport.send(payload)
    }

    func appendAudio(_ pcm16: Data) async throws {
        guard !pcm16.isEmpty else { return }
        let b64 = pcm16.base64EncodedString()
        try await transport.send(OutMessage.audioAppend(base64: b64).jsonEncoded())
    }

    func finishAndAwaitTranscript() async throws -> String {
        // If the server already errored or closed, surface that instead of
        // hitting a closed socket and reporting "not_connected".
        if let err = earlyError {
            os_log("finishAndAwaitTranscript bailing — earlyError=%{public}@", log: log, type: .error, err.code)
            throw err
        }
        os_log("sending input_audio_buffer.commit", log: log, type: .info)
        try await transport.send(OutMessage.audioCommit.jsonEncoded())
        os_log("commit sent, awaiting completed", log: log, type: .info)
        return try await withCheckedThrowingContinuation { cont in
            self.pendingTranscript = cont
        }
    }

    func cancel() {
        transport.close()
        if let p = pendingTranscript {
            pendingTranscript = nil
            p.resume(throwing: RealtimeError(code: "cancelled", message: ""))
        }
    }

    private func handleIncoming(_ data: Data) {
        if log.isEnabled(type: .info), let s = String(data: data, encoding: .utf8) {
            os_log("recv %{public}@", log: log, type: .info, s)
        }
        guard let event = try? RealtimeEvent.decode(data) else { return }
        switch event {
        case .completed(let text):
            if let p = pendingTranscript { pendingTranscript = nil; p.resume(returning: text) }
            transport.close()
        case .error(let code, let msg):
            let err = RealtimeError(code: code, message: msg)
            earlyError = err
            os_log("server error code=%{public}@ message=%{public}@", log: log, type: .error, code, msg)
            if let p = pendingTranscript { pendingTranscript = nil; p.resume(throwing: err) }
            transport.close()
        case .delta, .unknown:
            break
        }
    }

    private func handleClose(code: Int) {
        os_log("ws closed code=%d", log: log, type: .info, code)
        if earlyError == nil { earlyError = RealtimeError(code: "ws_closed_\(code)", message: "") }
        if let p = pendingTranscript {
            pendingTranscript = nil
            p.resume(throwing: RealtimeError(code: "ws_closed_\(code)", message: ""))
        }
    }
}

final class URLSessionWebSocketTransport: NSObject, RealtimeTransport, URLSessionWebSocketDelegate {
    var onMessage: ((Data) -> Void)?
    var onClose: ((Int) -> Void)?

    private var task: URLSessionWebSocketTask?
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    func connect(url: URL, headers: [String: String]) async throws {
        var req = URLRequest(url: url)
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        let t = session.webSocketTask(with: req)
        self.task = t
        t.resume()
        receiveLoop()
    }

    func send(_ data: Data) async throws {
        guard let t = task else { throw RealtimeError(code: "not_connected", message: "") }
        // OpenAI's Realtime API expects WebSocket text frames (opcode 0x1)
        // for JSON control messages, not binary frames. URLSessionWebSocketTask's
        // .data(...) sends binary; .string(...) sends text.
        let s = String(data: data, encoding: .utf8) ?? ""
        try await t.send(.string(s))
    }

    func close() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }

    private func receiveLoop() {
        guard let t = task else { return }
        t.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msg):
                switch msg {
                case .data(let d): self.onMessage?(d)
                case .string(let s): if let d = s.data(using: .utf8) { self.onMessage?(d) }
                @unknown default: break
                }
                self.receiveLoop()
            case .failure:
                self.onClose?(-1)
            }
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        onClose?(closeCode.rawValue)
    }
}
