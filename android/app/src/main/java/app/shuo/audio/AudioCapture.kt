package app.shuo.audio

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.isActive

class AudioCapture {

    companion object {
        const val SAMPLE_RATE = 24000
        private const val CHUNK_MS = 100
        private const val BYTES_PER_SAMPLE = 2
        val CHUNK_SIZE = SAMPLE_RATE * CHUNK_MS / 1000 * BYTES_PER_SAMPLE
    }

    fun record(): Flow<ByteArray> = flow {
        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufferSize = maxOf(minBuf, CHUNK_SIZE * 2)

        val recorder = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )

        recorder.startRecording()
        try {
            val chunk = ByteArray(CHUNK_SIZE)
            while (currentCoroutineContext().isActive) {
                val bytesRead = recorder.read(chunk, 0, chunk.size)
                if (bytesRead > 0) emit(chunk.copyOf(bytesRead))
            }
        } finally {
            recorder.stop()
            recorder.release()
        }
    }.flowOn(Dispatchers.IO)
}
