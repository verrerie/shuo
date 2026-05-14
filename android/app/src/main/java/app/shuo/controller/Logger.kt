package app.shuo.controller

import android.content.Context
import java.io.File
import java.time.Instant

class Logger(context: Context) {
    private val logFile = File(context.filesDir, "shuo.log")

    fun log(durationMs: Long, bytesSent: Int, lang: String, result: String) {
        val line = "${Instant.now()} | dur_ms=$durationMs bytes_sent=$bytesSent lang=$lang result=$result\n"
        logFile.appendText(line)
    }
}
