package app.shuo.ime

import android.inputmethodservice.InputMethodService
import android.view.View
import app.shuo.audio.AudioCapture
import app.shuo.controller.DictationController
import app.shuo.controller.DictationState
import app.shuo.controller.Logger
import app.shuo.network.RealtimeClient
import app.shuo.settings.ConfigStore
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

class ShuoIME : InputMethodService() {

    private lateinit var config: ConfigStore
    private lateinit var logger: Logger
    private lateinit var client: RealtimeClient
    private lateinit var controller: DictationController
    private lateinit var keyboardView: KeyboardView
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var sessionStartMs = 0L

    override fun onCreate() {
        super.onCreate()
        config = ConfigStore(this)
        logger = Logger(this)
    }

    override fun onCreateInputView(): View {
        keyboardView = KeyboardView(this)
        keyboardView.onStopClick = { controller.stop() }
        keyboardView.onLangClick = {
            val newLang = controller.cycleLanguage()
            keyboardView.render(controller.state.value, newLang)
            android.widget.Toast.makeText(this, newLang, android.widget.Toast.LENGTH_SHORT).show()
        }
        return keyboardView
    }

    override fun onStartInputView(info: android.view.inputmethod.EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        rebuildController()
        // drop(1) skips the StateFlow's initial Idle emission so we don't fire
        // switchToPreviousInputMethod() before start() runs.
        controller.state.drop(1).onEach { state ->
            val lang = config.defaultLanguage
            keyboardView.render(state, lang)
            if (state == DictationState.Idle) {
                switchToPreviousInputMethod()
            }
        }.launchIn(scope)
        sessionStartMs = System.currentTimeMillis()
        controller.start()
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        super.onFinishInputView(finishingInput)
        controller.cancel()
    }

    private fun rebuildController() {
        val audio = AudioCapture()
        client = RealtimeClient(config.apiKey)
        controller = DictationController(
            apiKey = config.apiKey,
            dailyCapReached = { config.capReached },
            connectAndReceive = { lang ->
                client.connect(lang).also {
                    audio.record().onEach { chunk ->
                        if (controller.state.value is DictationState.Recording) {
                            client.sendAudio(chunk)
                        }
                    }.launchIn(scope)
                }
            },
            recordAudio = { audio.record() },
            onTextReady = { text ->
                currentInputConnection?.commitText(text, 1)
            },
            onUsageSeconds = { secs ->
                config.addUsageSeconds(secs)
                logger.log(System.currentTimeMillis() - sessionStartMs, 0, config.defaultLanguage, "ok")
            },
            onCommitRequested = { client.commit() }
        )
    }
}
