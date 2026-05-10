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

    func start(language: String) async throws {
        // GA Realtime API: do NOT send OpenAI-Beta. The realtime=v1 header
        // pins us to the legacy beta endpoint, which doesn't have
        // gpt-realtime-whisper.
        try await transport.connect(url: url, headers: [
            "Authorization": "Bearer \(apiKey)"
        ])
        try await transport.send(OutMessage.sessionUpdate(model: model, language: language).jsonEncoded())
    }

    func appendAudio(_ pcm16: Data) async throws {
        let b64 = pcm16.base64EncodedString()
        try await transport.send(OutMessage.audioAppend(base64: b64).jsonEncoded())
    }

    func finishAndAwaitTranscript() async throws -> String {
        // If the server already errored or closed, surface that instead of
        // hitting a closed socket and reporting "not_connected".
        if let err = earlyError { throw err }
        try await transport.send(OutMessage.audioCommit.jsonEncoded())
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
        // Log every server message so we can see what's going on in Console.
        if let s = String(data: data, encoding: .utf8) {
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
        try await t.send(.data(data))
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
