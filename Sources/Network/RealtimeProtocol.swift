// Sources/Network/RealtimeProtocol.swift
import Foundation

enum OutMessage {
    case sessionUpdate(model: String, language: Language)
    case audioAppend(base64: String)
    case audioCommit

    func jsonEncoded() -> Data {
        switch self {
        case .sessionUpdate(let model, let language):
            // GA Realtime API shape (verified live 2026-05-10).
            // Hand-crafted as a string because the live server returns a
            // generic server_error for the same payload when it's serialized
            // by JSONSerialization with arbitrary key order or with escaped
            // slashes ("audio/pcm" → "audio\/pcm"). We reproduce the byte
            // sequence Node's JSON.stringify produced. Inputs are controlled
            // (model is a constant, language is one of zh/en/fr).
            //
            // noise_reduction: near_field — for headset / built-in laptop mic.
            // far_field is for speakerphone setups; not used here.
            let json = "{\"type\":\"session.update\",\"session\":{\"type\":\"transcription\",\"audio\":{\"input\":{\"format\":{\"type\":\"audio/pcm\",\"rate\":24000},\"transcription\":{\"model\":\"\(model)\",\"language\":\"\(language.rawValue)\"},\"noise_reduction\":{\"type\":\"near_field\"},\"turn_detection\":null}}}}"
            return Data(json.utf8)
        case .audioAppend(let b64):
            // Hand-built for the same reason as sessionUpdate, plus this is
            // on the per-chunk hot path (~3-10×/s) — one allocation instead
            // of three (dict + serializer + Data).
            return Data("{\"type\":\"input_audio_buffer.append\",\"audio\":\"\(b64)\"}".utf8)
        case .audioCommit:
            return Data("{\"type\":\"input_audio_buffer.commit\"}".utf8)
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
