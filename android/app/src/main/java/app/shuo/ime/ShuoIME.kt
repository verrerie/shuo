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
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

class ShuoIME : InputMethodService() {

    private lateinit var config: ConfigStore
    private lateinit var logger: Logger
    private lateinit var client: RealtimeClient
    private lateinit var audio: AudioCapture
    private lateinit var controller: DictationController
    private lateinit var keyboardView: KeyboardView
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var audioJob: Job? = null
    private var sessionStartMs = 0L

    override fun onCreate() {
        super.onCreate()
        config = ConfigStore(this)
        logger = Logger(this)
    }

    override fun onCreateInputView(): View {
        keyboardView = KeyboardView(this)
        keyboardView.onMicTap = {
            when (controller.state.value) {
                DictationState.Idle -> controller.start()
                is DictationState.Recording -> controller.stop()
                is DictationState.Error -> {
                    controller.cancel()
                    keyboardView.render(controller.state.value, config.defaultLanguage)
                }
                DictationState.Finalizing -> { /* wait for transcription */ }
            }
        }
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
        // drop(1) skips the initial Idle so we don't fire the side-effects
        // (audio start, etc.) before any user tap.
        controller.state.drop(1).onEach { state ->
            keyboardView.render(state, config.defaultLanguage)
            if (state is DictationState.Recording) startAudioForwarding()
            else stopAudioForwarding()
        }.launchIn(scope)
        // Render initial Idle frame; wait for the user to tap before recording.
        keyboardView.render(controller.state.value, config.defaultLanguage)
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        super.onFinishInputView(finishingInput)
        controller.cancel()
        stopAudioForwarding()
    }

    private fun startAudioForwarding() {
        audioJob?.cancel()
        sessionStartMs = System.currentTimeMillis()
        audioJob = audio.record()
            .onEach { chunk -> client.sendAudio(chunk) }
            .launchIn(scope)
    }

    private fun stopAudioForwarding() {
        audioJob?.cancel()
        audioJob = null
    }

    private fun rebuildController() {
        audio = AudioCapture()
        client = RealtimeClient(config.apiKey)
        controller = DictationController(
            apiKey = config.apiKey,
            dailyCapReached = { config.capReached },
            // Audio forwarding is now driven by the state observer in
            // onStartInputView — keeps the per-session audio job lifecycle
            // tied to the Recording state, not entangled with this lambda.
            connectAndReceive = { lang -> client.connect(lang) },
            recordAudio = { emptyFlow() },
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
