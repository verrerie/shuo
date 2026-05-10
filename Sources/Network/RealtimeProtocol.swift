// Sources/Network/RealtimeProtocol.swift
import Foundation

enum OutMessage {
    case sessionUpdate(model: String, language: String)
    case audioAppend(base64: String)
    case audioCommit

    func jsonEncoded() throws -> Data {
        switch self {
        case .sessionUpdate(let model, let language):
            let body: [String: Any] = [
                "type": "transcription_session.update",
                "session": [
                    "input_audio_format": "pcm16",
                    "input_audio_transcription": [
                        "model": model,
                        "language": language
                    ]
                    // turn_detection intentionally omitted = null on server
                ]
            ]
            return try JSONSerialization.data(withJSONObject: body)
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
