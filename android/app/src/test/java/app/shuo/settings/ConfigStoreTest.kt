package app.shuo.settings

import org.junit.Assert.*
import org.junit.Test

class ConfigStoreTest {

    @Test
    fun `dailyUsageSeconds resets to 0 on a new day`() {
        val store = InMemoryConfigStore()
        store.setUsage("2026-01-01", 3000)
        store.currentDay = "2026-01-02"
        assertEquals(0, store.dailyUsageSeconds)
    }

    @Test
    fun `addUsageSeconds accumulates on the same day`() {
        val store = InMemoryConfigStore()
        store.currentDay = "2026-01-01"
        store.setUsage("2026-01-01", 100)
        store.addUsageSeconds(50)
        assertEquals(150, store.dailyUsageSeconds)
    }

    @Test
    fun `capReached returns true when usage meets cap`() {
        val store = InMemoryConfigStore()
        store.currentDay = "2026-01-01"
        store.setUsage("2026-01-01", 3600)
        store.dailyCapMinutes = 60
        assertTrue(store.capReached)
    }

    @Test
    fun `capReached returns false when usage is below cap`() {
        val store = InMemoryConfigStore()
        store.currentDay = "2026-01-01"
        store.setUsage("2026-01-01", 1800)
        store.dailyCapMinutes = 60
        assertFalse(store.capReached)
    }
}

// Test double — no Android deps
class InMemoryConfigStore {
    var apiKey: String = ""
    var defaultLanguage: String = "zh"
    var dailyCapMinutes: Int = 60
    var currentDay: String = "2026-01-01"

    private var savedDay: String = ""
    private var savedSeconds: Int = 0

    val dailyUsageSeconds: Int
        get() = if (savedDay == currentDay) savedSeconds else 0

    val capReached: Boolean
        get() = dailyUsageSeconds >= dailyCapMinutes * 60

    fun setUsage(day: String, seconds: Int) {
        savedDay = day
        savedSeconds = seconds
    }

    fun addUsageSeconds(seconds: Int) {
        val current = dailyUsageSeconds
        savedDay = currentDay
        savedSeconds = current + seconds
    }
}
