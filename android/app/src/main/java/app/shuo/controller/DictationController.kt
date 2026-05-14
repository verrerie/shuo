package app.shuo.controller

import app.shuo.network.RealtimeEvent
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

sealed class DictationState {
    object Idle : DictationState()
    data class Recording(val language: String) : DictationState()
    object Finalizing : DictationState()
    data class Error(val message: String) : DictationState()
}

class DictationController(
    private val apiKey: String,
    private val dailyCapReached: () -> Boolean,
    private val connectAndReceive: (language: String) -> Flow<RealtimeEvent>,
    private val recordAudio: () -> Flow<ByteArray>,
    val onTextReady: (String) -> Unit,
    private val onUsageSeconds: (Int) -> Unit,
    private val onCommitRequested: () -> Unit = {},
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
) {
    private val languages = listOf("zh", "en", "fr")
    private var languageIndex = 0
    private val language: String get() = languages[languageIndex]

    private val _state = MutableStateFlow<DictationState>(DictationState.Idle)
    val state: StateFlow<DictationState> = _state.asStateFlow()

    private var job: Job? = null
    private var sessionStartMs: Long = 0L

    fun start() {
        if (_state.value != DictationState.Idle) return
        if (apiKey.isBlank()) { _state.value = DictationState.Error("no_api_key"); return }
        if (dailyCapReached()) { _state.value = DictationState.Error("cap_reached"); return }

        sessionStartMs = System.currentTimeMillis()
        _state.value = DictationState.Recording(language)

        job = scope.launch {
            val events = connectAndReceive(language)
            launch {
                events.collect { event ->
                    when (event) {
                        is RealtimeEvent.Completed -> {
                            val secs = ((System.currentTimeMillis() - sessionStartMs) / 1000).toInt()
                            onUsageSeconds(secs)
                            _state.value = DictationState.Idle
                            onTextReady(event.text)
                        }
                        is RealtimeEvent.Error -> {
                            _state.value = DictationState.Error(event.code)
                        }
                        else -> {}
                    }
                }
            }
            recordAudio()
                .takeWhile { _state.value is DictationState.Recording }
                .collect { }
        }
    }

    fun stop() {
        if (_state.value !is DictationState.Recording) return
        _state.value = DictationState.Finalizing
        onCommitRequested()
    }

    fun cycleLanguage(): String {
        languageIndex = (languageIndex + 1) % languages.size
        return language
    }

    fun cancel() {
        job?.cancel()
        _state.value = DictationState.Idle
    }
}
