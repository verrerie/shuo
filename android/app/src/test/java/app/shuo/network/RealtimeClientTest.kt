package app.shuo.network

import org.junit.Assert.*
import org.junit.Test
import java.util.Base64

class RealtimeClientTest {

    @Test
    fun `buildSessionUpdate matches GA Realtime API shape`() {
        val json = RealtimeClient.buildSessionUpdateJson("zh")
        assertTrue(json.contains("\"type\":\"session.update\""))
        assertTrue(json.contains("\"type\":\"transcription\""))
        assertTrue(json.contains("\"language\":\"zh\""))
        assertTrue(json.contains("\"model\":\"gpt-realtime-whisper\""))
        assertTrue(json.contains("\"type\":\"audio/pcm\""))
        assertTrue(json.contains("\"rate\":24000"))
        assertTrue(json.contains("\"type\":\"near_field\""))
        assertTrue(json.contains("\"turn_detection\":null"))
    }

    @Test
    fun `buildAppendJson encodes PCM bytes as base64`() {
        val bytes = byteArrayOf(1, 2, 3, 4)
        val json = RealtimeClient.buildAppendJson(bytes)
        val expectedBase64 = Base64.getEncoder().encodeToString(bytes)
        assertTrue(json.contains("\"type\":\"input_audio_buffer.append\""))
        assertTrue(json.contains(expectedBase64))
    }

    @Test
    fun `buildCommitJson has correct type`() {
        val json = RealtimeClient.buildCommitJson()
        assertEquals("""{"type":"input_audio_buffer.commit"}""", json)
    }
}
