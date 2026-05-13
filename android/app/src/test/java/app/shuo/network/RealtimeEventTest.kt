package app.shuo.network

import org.junit.Assert.assertEquals
import org.junit.Test

class RealtimeEventTest {

    @Test
    fun `Completed holds transcript text`() {
        val event = RealtimeEvent.Completed("你好")
        assertEquals("你好", event.text)
    }

    @Test
    fun `Error holds code string`() {
        val event = RealtimeEvent.Error("401")
        assertEquals("401", event.code)
    }

    @Test
    fun `Delta holds partial text`() {
        val event = RealtimeEvent.Delta("hel")
        assertEquals("hel", event.text)
    }

    @Test
    fun `Closed holds numeric code`() {
        val event = RealtimeEvent.Closed(1000)
        assertEquals(1000, event.code)
    }
}
