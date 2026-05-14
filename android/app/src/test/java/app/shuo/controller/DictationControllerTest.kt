package app.shuo.controller

import app.shuo.network.RealtimeEvent
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class DictationControllerTest {

    private val testDispatcher = StandardTestDispatcher()

    @Before fun setUp() { Dispatchers.setMain(testDispatcher) }
    @After fun tearDown() { Dispatchers.resetMain() }

    private fun makeController(
        apiKey: String = "sk-test",
        capReached: Boolean = false,
        events: List<RealtimeEvent> = emptyList()
    ): Pair<DictationController, MutableList<String>> {
        val injected = mutableListOf<String>()
        val ctrl = DictationController(
            apiKey = apiKey,
            dailyCapReached = { capReached },
            connectAndReceive = { _ -> events.asFlow() },
            recordAudio = { emptyFlow() },
            onTextReady = { injected.add(it) },
            onUsageSeconds = {}
        )
        return ctrl to injected
    }

    @Test
    fun `initial state is Idle`() {
        val (ctrl, _) = makeController()
        assertEquals(DictationState.Idle, ctrl.state.value)
    }

    @Test
    fun `start transitions to Recording`() = runTest {
        val (ctrl, _) = makeController(events = listOf(RealtimeEvent.Completed("hello")))
        ctrl.start()
        assertEquals(DictationState.Recording("zh"), ctrl.state.value)
    }

    @Test
    fun `start when cap reached stays Idle with CapReached error`() = runTest {
        val (ctrl, _) = makeController(capReached = true)
        ctrl.start()
        assertEquals(DictationState.Error("cap_reached"), ctrl.state.value)
    }

    @Test
    fun `start with blank API key emits Error`() = runTest {
        val (ctrl, _) = makeController(apiKey = "")
        ctrl.start()
        assertEquals(DictationState.Error("no_api_key"), ctrl.state.value)
    }

    @Test
    fun `Completed event fires onTextReady and returns to Idle`() = runTest {
        val (ctrl, injected) = makeController(
            events = listOf(RealtimeEvent.Connected, RealtimeEvent.Completed("你好"))
        )
        ctrl.start()
        advanceUntilIdle()
        assertEquals(listOf("你好"), injected)
        assertEquals(DictationState.Idle, ctrl.state.value)
    }

    @Test
    fun `Error event transitions to Error state`() = runTest {
        val (ctrl, _) = makeController(
            events = listOf(RealtimeEvent.Error("401"))
        )
        ctrl.start()
        advanceUntilIdle()
        assertEquals(DictationState.Error("401"), ctrl.state.value)
    }

    @Test
    fun `stop transitions Recording to Finalizing`() = runTest {
        val (ctrl, _) = makeController()
        ctrl.start()
        ctrl.stop()
        assertEquals(DictationState.Finalizing, ctrl.state.value)
    }

    @Test
    fun `cycleLanguage rotates zh en fr zh`() {
        val (ctrl, _) = makeController()
        assertEquals("en", ctrl.cycleLanguage())
        assertEquals("fr", ctrl.cycleLanguage())
        assertEquals("zh", ctrl.cycleLanguage())
    }

    @Test
    fun `cancel returns to Idle from Recording`() = runTest {
        val (ctrl, _) = makeController()
        ctrl.start()
        ctrl.cancel()
        assertEquals(DictationState.Idle, ctrl.state.value)
    }
}
