package app.shuo.network

import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.serialization.json.*
import okhttp3.*
import java.util.Base64

class RealtimeClient(private val apiKey: String) {

    private val httpClient = OkHttpClient()
    private var webSocket: WebSocket? = null

    fun connect(language: String): Flow<RealtimeEvent> = callbackFlow {
        // GA Realtime API: do NOT send the OpenAI-Beta header. The realtime=v1
        // value pins us to the legacy beta endpoint, which doesn't have
        // gpt-realtime-whisper. Matches Sources/Network/RealtimeClient.swift.
        val request = Request.Builder()
            .url("wss://api.openai.com/v1/realtime?intent=transcription")
            .header("Authorization", "Bearer $apiKey")
            .build()

        val listener = object : WebSocketListener() {
            override fun onOpen(ws: WebSocket, response: Response) {
                webSocket = ws
                trySend(RealtimeEvent.Connected)
                ws.send(buildSessionUpdateJson(language))
            }

            override fun onMessage(ws: WebSocket, text: String) {
                val json = Json.parseToJsonElement(text).jsonObject
                when (json["type"]?.jsonPrimitive?.content) {
                    "conversation.item.input_audio_transcription.completed" -> {
                        val transcript = json["transcript"]?.jsonPrimitive?.content ?: ""
                        trySend(RealtimeEvent.Completed(transcript))
                    }
                    "conversation.item.input_audio_transcription.delta" -> {
                        val delta = json["delta"]?.jsonPrimitive?.content ?: ""
                        trySend(RealtimeEvent.Delta(delta))
                    }
                    "error" -> {
                        val code = json["error"]?.jsonObject
                            ?.get("code")?.jsonPrimitive?.content ?: "unknown"
                        trySend(RealtimeEvent.Error(code))
                    }
                }
            }

            override fun onClosing(ws: WebSocket, code: Int, reason: String) {
                trySend(RealtimeEvent.Closed(code))
                close()
            }

            override fun onFailure(ws: WebSocket, t: Throwable, response: Response?) {
                // Prefer the HTTP status code when the WebSocket upgrade is
                // rejected — that's where 401 (bad API key) surfaces. Falls
                // back to the throwable message for genuine network errors.
                val code = response?.code?.toString() ?: t.message ?: "connection_failed"
                android.util.Log.w("RealtimeClient", "WebSocket onFailure: code=$code msg=${t.message}", t)
                trySend(RealtimeEvent.Error(code))
                close()
            }
        }

        httpClient.newWebSocket(request, listener)
        awaitClose {
            webSocket?.close(1000, null)
            webSocket = null
        }
    }

    fun sendAudio(pcmBytes: ByteArray) {
        webSocket?.send(buildAppendJson(pcmBytes))
    }

    fun commit() {
        webSocket?.send(buildCommitJson())
    }

    companion object {
        // GA Realtime API shape — matches the macOS Swift implementation
        // (see Sources/Network/RealtimeProtocol.swift in the same repo).
        fun buildSessionUpdateJson(language: String): String =
            buildJsonObject {
                put("type", "session.update")
                putJsonObject("session") {
                    put("type", "transcription")
                    putJsonObject("audio") {
                        putJsonObject("input") {
                            putJsonObject("format") {
                                put("type", "audio/pcm")
                                put("rate", 24000)
                            }
                            putJsonObject("transcription") {
                                put("model", "gpt-realtime-whisper")
                                put("language", language)
                            }
                            putJsonObject("noise_reduction") {
                                put("type", "near_field")
                            }
                            put("turn_detection", JsonNull)
                        }
                    }
                }
            }.toString()

        fun buildAppendJson(pcmBytes: ByteArray): String {
            val base64 = Base64.getEncoder().encodeToString(pcmBytes)
            return buildJsonObject {
                put("type", "input_audio_buffer.append")
                put("audio", base64)
            }.toString()
        }

        fun buildCommitJson(): String =
            buildJsonObject {
                put("type", "input_audio_buffer.commit")
            }.toString()
    }
}
