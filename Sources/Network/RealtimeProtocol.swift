// Sources/Network/RealtimeProtocol.swift
import Foundation

enum OutMessage {
    case sessionUpdate(model: String, language: String)
    case audioAppend(base64: String)
    case audioCommit

    func jsonEncoded() throws -> Data {
        switch self {
        case .sessionUpdate(let model, let language):
            // GA Realtime API shape (verified live 2026-05-10).
            // Hand-crafted as a string because the live server returns a
            // generic server_error for the same payload when it's serialized
            // by JSONSerialization with arbitrary key order (or with escaped
            // slashes). Node's JSON.stringify produced a working payload in
            // a specific order; we reproduce it byte-for-byte. Inputs are
            // controlled (model is a constant, language is one of zh/en/fr).
            let escapedModel = model.replacingOccurrences(of: "\"", with: "\\\"")
            let escapedLang = language.replacingOccurrences(of: "\"", with: "\\\"")
            let json = "{\"type\":\"session.update\",\"session\":{\"type\":\"transcription\",\"audio\":{\"input\":{\"format\":{\"type\":\"audio/pcm\",\"rate\":24000},\"transcription\":{\"model\":\"\(escapedModel)\",\"language\":\"\(escapedLang)\"},\"turn_detection\":null}}}}"
            return Data(json.utf8)
        case .audioAppend(let b64):
            return try JSONSerialization.data(withJSONObject: [
                "type": "input_audio_buffer.append",
                "audio": b64
            ])
        case .audioCommit:
            return try JSONSerialization.data(withJSONObject: [
                "type": "input_audio_buffer.commit"
            ])
        }
    }
}

enum RealtimeEvent: Equatable {
    case completed(text: String)
    case delta(text: String)
    case error(code: String, message: String)
    case unknown(type: String)

    static func decode(_ data: Data) throws -> RealtimeEvent {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else {
            return .unknown(type: "<malformed>")
        }
        switch type {
        case "conversation.item.input_audio_transcription.completed":
            let text = (obj["transcript"] as? String) ?? ""
            return .completed(text: text)
        case "conversation.item.input_audio_transcription.delta":
            let text = (obj["delta"] as? String) ?? ""
            return .delta(text: text)
        case "error":
            let err = obj["error"] as? [String: Any]
            return .error(code: (err?["code"] as? String) ?? "unknown",
                          message: (err?["message"] as? String) ?? "")
        default:
            return .unknown(type: type)
        }
    }
}
