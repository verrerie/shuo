# Shuo Android Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native Android IME (pure voice keyboard) that auto-starts recording on activation, streams audio to OpenAI Realtime API, and injects the transcribed text into the focused input field.

**Architecture:** Six components mirroring the macOS version — `ShuoIME` (InputMethodService), `AudioCapture` (AudioRecord Flow), `RealtimeClient` (OkHttp WebSocket), `DictationController` (state machine), `KeyboardView` (custom View), `ConfigStore` (EncryptedSharedPreferences). The IME auto-starts on `onStartInputView()` and auto-switches back to the previous keyboard after text injection.

**Tech Stack:** Kotlin, OkHttp 4.x for WebSocket, kotlinx.serialization for JSON, Jetpack Security for encrypted prefs, Kotlin Coroutines + Flow for async, JUnit 4 + MockK for tests.

---

## File Map

```
android/
  app/
    src/
      main/
        java/app/shuo/
          network/
            RealtimeEvent.kt          sealed class for all server events
            RealtimeClient.kt         OkHttp WS — one socket per turn
          audio/
            AudioCapture.kt           AudioRecord → Flow<ByteArray>
          controller/
            DictationController.kt    state machine + daily cap + log
          settings/
            ConfigStore.kt            EncryptedSharedPreferences wrapper
            SettingsActivity.kt       launcher UI — API key, lang, cap
          ime/
            ShuoIME.kt                InputMethodService subclass
            KeyboardView.kt           custom View — pulse, stop, lang
        res/
          layout/
            keyboard_view.xml
            activity_settings.xml
          xml/
            input_method.xml
          values/
            strings.xml
      test/
        java/app/shuo/
          network/
            RealtimeEventTest.kt
            RealtimeClientTest.kt
          controller/
            DictationControllerTest.kt
          settings/
            ConfigStoreTest.kt
  build.gradle.kts
  settings.gradle.kts
  gradle.properties
```

---

## Task 1: Project Scaffold

**Files:**
- Create: `android/settings.gradle.kts`
- Create: `android/build.gradle.kts`
- Create: `android/gradle.properties`
- Create: `android/app/build.gradle.kts`
- Create: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/res/xml/input_method.xml`
- Create: `android/app/src/main/res/values/strings.xml`

- [ ] **Step 1: Create `android/settings.gradle.kts`**

```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "shuo-android"
include(":app")
```

- [ ] **Step 2: Create `android/build.gradle.kts`**

```kotlin
plugins {
    id("com.android.application") version "8.3.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.23" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "1.9.23" apply false
}
```

- [ ] **Step 3: Create `android/gradle.properties`**

```properties
android.useAndroidX=true
kotlin.code.style=official
```

- [ ] **Step 4: Create `android/app/build.gradle.kts`**

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "app.shuo"
    compileSdk = 34

    defaultConfig {
        applicationId = "app.shuo"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.0")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("androidx.appcompat:appcompat:1.7.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("io.mockk:mockk:1.13.10")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.0")
}
```

- [ ] **Step 5: Create `android/app/src/main/AndroidManifest.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:label="@string/app_name"
        android:theme="@style/Theme.AppCompat">

        <activity
            android:name=".settings.SettingsActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".ime.ShuoIME"
            android:exported="true"
            android:permission="android.permission.BIND_INPUT_METHOD">
            <intent-filter>
                <action android:name="android.view.InputMethod" />
            </intent-filter>
            <meta-data
                android:name="android.view.im"
                android:resource="@xml/input_method" />
        </service>

    </application>

</manifest>
```

- [ ] **Step 6: Create `android/app/src/main/res/xml/input_method.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<input-method xmlns:android="http://schemas.android.com/apk/res/android">
    <subtype
        android:label="@string/subtype_voice"
        android:imeSubtypeMode="voice"
        android:imeSubtypeLocale="*" />
</input-method>
```

- [ ] **Step 7: Create `android/app/src/main/res/values/strings.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Shuo</string>
    <string name="subtype_voice">Voice</string>
    <string name="settings_api_key_hint">OpenAI API key (sk-…)</string>
    <string name="settings_save">Save</string>
    <string name="error_no_api_key">Open Shuo settings and enter your API key</string>
    <string name="error_cap_reached">Daily cap reached</string>
    <string name="error_api_rejected">API key rejected — open Settings</string>
    <string name="error_generic">Error — check API key</string>
</resources>
```

- [ ] **Step 8: Verify the project builds**

```bash
cd android && ./gradlew assembleDebug
```

Expected: `BUILD SUCCESSFUL`. Fix any dependency resolution errors before continuing.

- [ ] **Step 9: Commit**

```bash
git add android/
git commit -m "chore(android): scaffold Android project"
```

---

## Task 2: RealtimeEvent

**Files:**
- Create: `android/app/src/main/java/app/shuo/network/RealtimeEvent.kt`
- Create: `android/app/src/test/java/app/shuo/network/RealtimeEventTest.kt`

- [ ] **Step 1: Write the failing test**

`android/app/src/test/java/app/shuo/network/RealtimeEventTest.kt`:

```kotlin
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests "app.shuo.network.RealtimeEventTest"
```

Expected: FAIL — `RealtimeEvent` not found.

- [ ] **Step 3: Create `android/app/src/main/java/app/shuo/network/RealtimeEvent.kt`**

```kotlin
package app.shuo.network

sealed class RealtimeEvent {
    object Connected : RealtimeEvent()
    data class Delta(val text: String) : RealtimeEvent()
    data class Completed(val text: String) : RealtimeEvent()
    data class Error(val code: String) : RealtimeEvent()
    data class Closed(val code: Int) : RealtimeEvent()
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests "app.shuo.network.RealtimeEventTest"
```

Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/app/shuo/network/RealtimeEvent.kt \
        android/app/src/test/java/app/shuo/network/RealtimeEventTest.kt
git commit -m "feat(android): add RealtimeEvent sealed class"
```

---

## Task 3: RealtimeClient

**Files:**
- Create: `android/app/src/main/java/app/shuo/network/RealtimeClient.kt`
- Create: `android/app/src/test/java/app/shuo/network/RealtimeClientTest.kt`

- [ ] **Step 1: Write the failing tests**

`android/app/src/test/java/app/shuo/network/RealtimeClientTest.kt`:

```kotlin
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests "app.shuo.network.RealtimeClientTest"
```

Expected: FAIL — `RealtimeClient` not found.

- [ ] **Step 3: Create `android/app/src/main/java/app/shuo/network/RealtimeClient.kt`**

```kotlin
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
        val request = Request.Builder()
            .url("wss://api.openai.com/v1/realtime?intent=transcription")
            .header("Authorization", "Bearer $apiKey")
            .header("OpenAI-Beta", "realtime=v1")
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
                trySend(RealtimeEvent.Error(t.message ?: "connection_failed"))
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests "app.shuo.network.RealtimeClientTest"
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/app/shuo/network/RealtimeClient.kt \
        android/app/src/test/java/app/shuo/network/RealtimeClientTest.kt
git commit -m "feat(android): add RealtimeClient with OkHttp WebSocket"
```

---

## Task 4: AudioCapture

**Files:**
- Create: `android/app/src/main/java/app/shuo/audio/AudioCapture.kt`

`AudioRecord` requires a real device to test. We define the interface and verify it compiles; device testing happens at integration.

- [ ] **Step 1: Create `android/app/src/main/java/app/shuo/audio/AudioCapture.kt`**

```kotlin
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
```

- [ ] **Step 2: Verify it compiles**

```bash
cd android && ./gradlew :app:compileDebugKotlin
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/java/app/shuo/audio/AudioCapture.kt
git commit -m "feat(android): add AudioCapture (AudioRecord → Flow<ByteArray>)"
```

---

## Task 5: ConfigStore

**Files:**
- Create: `android/app/src/main/java/app/shuo/settings/ConfigStore.kt`
- Create: `android/app/src/test/java/app/shuo/settings/ConfigStoreTest.kt`

- [ ] **Step 1: Write the failing tests**

`android/app/src/test/java/app/shuo/settings/ConfigStoreTest.kt`:

```kotlin
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests "app.shuo.settings.ConfigStoreTest"
```

Expected: FAIL — `InMemoryConfigStore` not found.

- [ ] **Step 3: Move the test double to the test file and create `ConfigStore.kt`**

The test file already contains `InMemoryConfigStore`. Now create the production class:

`android/app/src/main/java/app/shuo/settings/ConfigStore.kt`:

```kotlin
package app.shuo.settings

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import java.time.LocalDate

class ConfigStore(context: Context) {

    // androidx.security-crypto 1.0.0 API — MasterKey (singular) only exists
    // in 1.1.0-alpha. We pin 1.0.0 for stability, so use MasterKeys + alias.
    private val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)

    private val secure: SharedPreferences = EncryptedSharedPreferences.create(
        "shuo_secure",
        masterKeyAlias,
        context,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    private val prefs: SharedPreferences =
        context.getSharedPreferences("shuo", Context.MODE_PRIVATE)

    var apiKey: String
        get() = secure.getString("openai_api_key", "") ?: ""
        set(value) { secure.edit().putString("openai_api_key", value).apply() }

    var defaultLanguage: String
        get() = prefs.getString("default_language", "zh") ?: "zh"
        set(value) { prefs.edit().putString("default_language", value).apply() }

    var dailyCapMinutes: Int
        get() = prefs.getInt("daily_cap_minutes", 60)
        set(value) { prefs.edit().putInt("daily_cap_minutes", value).apply() }

    val dailyUsageSeconds: Int
        get() {
            val today = LocalDate.now().toString()
            val savedDay = prefs.getString("usage_day", "") ?: ""
            return if (savedDay == today) prefs.getInt("daily_usage_seconds", 0) else 0
        }

    val capReached: Boolean
        get() = dailyUsageSeconds >= dailyCapMinutes * 60

    fun addUsageSeconds(seconds: Int) {
        val today = LocalDate.now().toString()
        val current = dailyUsageSeconds
        prefs.edit()
            .putString("usage_day", today)
            .putInt("daily_usage_seconds", current + seconds)
            .apply()
    }

    fun wipeApiKey() {
        secure.edit().remove("openai_api_key").apply()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests "app.shuo.settings.ConfigStoreTest"
```

Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/app/shuo/settings/ConfigStore.kt \
        android/app/src/test/java/app/shuo/settings/ConfigStoreTest.kt
git commit -m "feat(android): add ConfigStore with encrypted API key storage"
```

---

## Task 6: DictationController

**Files:**
- Create: `android/app/src/main/java/app/shuo/controller/DictationController.kt`
- Create: `android/app/src/test/java/app/shuo/controller/DictationControllerTest.kt`

- [ ] **Step 1: Write the failing tests**

`android/app/src/test/java/app/shuo/controller/DictationControllerTest.kt`:

```kotlin
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

    // Controller eagerly creates a scope on Dispatchers.Main, which is unbound
    // on JVM unit tests — redirect to a test dispatcher so construction works
    // and advanceUntilIdle() drives the controller's coroutines.
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests "app.shuo.controller.DictationControllerTest"
```

Expected: FAIL — `DictationController` not found.

- [ ] **Step 3: Create `android/app/src/main/java/app/shuo/controller/DictationController.kt`**

```kotlin
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
    // Called exactly once when the user taps Stop — caller sends commit to the WebSocket.
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
                .collect { /* chunks forwarded by ShuoIME via client.sendAudio */ }
        }
    }

    fun stop() {
        if (_state.value !is DictationState.Recording) return
        _state.value = DictationState.Finalizing
        onCommitRequested()  // single call — caller sends commit to WebSocket
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests "app.shuo.controller.DictationControllerTest"
```

Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/app/shuo/controller/DictationController.kt \
        android/app/src/test/java/app/shuo/controller/DictationControllerTest.kt
git commit -m "feat(android): add DictationController state machine"
```

---

## Task 7: KeyboardView

**Files:**
- Create: `android/app/src/main/res/layout/keyboard_view.xml`
- Create: `android/app/src/main/java/app/shuo/ime/KeyboardView.kt`

- [ ] **Step 1: Create `android/app/src/main/res/layout/keyboard_view.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="200dp"
    android:background="#1A1A1A">

    <!-- Pulse circle -->
    <View
        android:id="@+id/pulse_circle"
        android:layout_width="48dp"
        android:layout_height="48dp"
        android:layout_gravity="center"
        android:background="@drawable/circle_indicator" />

    <!-- Language label (top-left) -->
    <TextView
        android:id="@+id/lang_button"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="top|start"
        android:layout_margin="16dp"
        android:textColor="#FFFFFF"
        android:textSize="16sp"
        android:text="zh"
        android:padding="8dp" />

    <!-- Stop button (bottom-center) -->
    <TextView
        android:id="@+id/stop_button"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="bottom|center_horizontal"
        android:layout_marginBottom="24dp"
        android:text="■ Stop"
        android:textColor="#FFFFFF"
        android:textSize="18sp"
        android:padding="12dp" />

    <!-- Status label (center-bottom, above stop button) -->
    <TextView
        android:id="@+id/status_label"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="center_horizontal|bottom"
        android:layout_marginBottom="72dp"
        android:textColor="#AAAAAA"
        android:textSize="13sp"
        android:visibility="gone" />

</FrameLayout>
```

- [ ] **Step 2: Create the circle drawable**

`android/app/src/main/res/drawable/circle_indicator.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="oval">
    <solid android:color="#4CAF50" />
</shape>
```

- [ ] **Step 3: Create `android/app/src/main/java/app/shuo/ime/KeyboardView.kt`**

```kotlin
package app.shuo.ime

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.widget.FrameLayout
import android.widget.TextView
import android.view.View
import app.shuo.R
import app.shuo.controller.DictationState

class KeyboardView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : FrameLayout(context, attrs) {

    private val pulseCircle: View
    private val stopButton: TextView
    private val langButton: TextView
    private val statusLabel: TextView
    private var pulseAnimator: ObjectAnimator? = null

    var onStopClick: (() -> Unit)? = null
    var onLangClick: (() -> Unit)? = null

    init {
        LayoutInflater.from(context).inflate(R.layout.keyboard_view, this, true)
        pulseCircle = findViewById(R.id.pulse_circle)
        stopButton = findViewById(R.id.stop_button)
        langButton = findViewById(R.id.lang_button)
        statusLabel = findViewById(R.id.status_label)
        stopButton.setOnClickListener { onStopClick?.invoke() }
        langButton.setOnClickListener { onLangClick?.invoke() }
    }

    fun render(state: DictationState, language: String) {
        langButton.text = language
        when (state) {
            is DictationState.Recording -> {
                stopButton.visibility = VISIBLE
                statusLabel.visibility = GONE
                startPulse()
            }
            is DictationState.Finalizing -> {
                stopButton.visibility = INVISIBLE
                statusLabel.visibility = VISIBLE
                statusLabel.text = "…"
                stopPulse()
            }
            is DictationState.Error -> {
                stopButton.visibility = GONE
                statusLabel.visibility = VISIBLE
                statusLabel.text = context.getString(errorStringRes(state.message))
                stopPulse()
            }
            DictationState.Idle -> {
                stopButton.visibility = GONE
                statusLabel.visibility = GONE
                stopPulse()
            }
        }
    }

    // Maps controller error codes (raw from RealtimeEvent.Error or controller-internal
    // strings like "no_api_key") to user-facing strings. Owned by the UI so the
    // controller can stay code-agnostic.
    private fun errorStringRes(code: String): Int = when (code) {
        "no_api_key" -> R.string.error_no_api_key
        "cap_reached" -> R.string.error_cap_reached
        "401" -> R.string.error_api_rejected
        else -> R.string.error_generic
    }

    private fun startPulse() {
        if (pulseAnimator != null) return
        pulseAnimator = ObjectAnimator.ofFloat(pulseCircle, "alpha", 0.4f, 1.0f).apply {
            duration = 1000
            repeatMode = ValueAnimator.REVERSE
            repeatCount = ValueAnimator.INFINITE
            start()
        }
    }

    private fun stopPulse() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        pulseCircle.alpha = 1.0f
    }
}
```

- [ ] **Step 4: Verify it compiles**

```bash
cd android && ./gradlew :app:compileDebugKotlin
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/app/shuo/ime/KeyboardView.kt \
        android/app/src/main/res/layout/keyboard_view.xml \
        android/app/src/main/res/drawable/circle_indicator.xml
git commit -m "feat(android): add KeyboardView with pulse animation"
```

---

## Task 8: Logger

**Files:**
- Create: `android/app/src/main/java/app/shuo/controller/Logger.kt`

- [ ] **Step 1: Create `android/app/src/main/java/app/shuo/controller/Logger.kt`**

```kotlin
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
```

- [ ] **Step 2: Verify it compiles**

```bash
cd android && ./gradlew :app:compileDebugKotlin
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/java/app/shuo/controller/Logger.kt
git commit -m "feat(android): add Logger"
```

---

## Task 9: ShuoIME

**Files:**
- Create: `android/app/src/main/java/app/shuo/ime/ShuoIME.kt`

- [ ] **Step 1: Create `android/app/src/main/java/app/shuo/ime/ShuoIME.kt`**

```kotlin
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
            // 1-second toast matching macOS behaviour
            android.widget.Toast.makeText(this, newLang, android.widget.Toast.LENGTH_SHORT).show()
        }
        return keyboardView
    }

    override fun onStartInputView(info: android.view.inputmethod.EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        rebuildController()
        // drop(1) skips the StateFlow's initial Idle emission so we don't
        // fire switchToPreviousInputMethod() before start() runs.
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
                // Start forwarding audio chunks to the WebSocket while recording.
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
            onCommitRequested = { client.commit() }  // called exactly once by stop()
        )
    }
}
```

> **Note on audio forwarding:** The `connectAndReceive` lambda starts the audio capture and forwards chunks to the client while the controller is in `Recording` state. When the controller transitions to `Finalizing` (via `stop()`), `commit()` is sent. This mirrors the macOS DictationController's coordination pattern.

- [ ] **Step 2: Verify it compiles**

```bash
cd android && ./gradlew :app:compileDebugKotlin
```

Expected: `BUILD SUCCESSFUL`. Fix any import errors.

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/java/app/shuo/ime/ShuoIME.kt
git commit -m "feat(android): add ShuoIME InputMethodService"
```

---

## Task 10: SettingsActivity

**Files:**
- Create: `android/app/src/main/res/layout/activity_settings.xml`
- Create: `android/app/src/main/java/app/shuo/settings/SettingsActivity.kt`

- [ ] **Step 1: Create `android/app/src/main/res/layout/activity_settings.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="24dp">

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Shuo"
        android:textSize="24sp"
        android:textStyle="bold"
        android:layout_marginBottom="24dp" />

    <!-- API Key -->
    <TextView android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="OpenAI API Key" />
    <EditText
        android:id="@+id/api_key_field"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:hint="@string/settings_api_key_hint"
        android:inputType="textPassword"
        android:layout_marginBottom="16dp" />

    <!-- Language -->
    <TextView android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Default language" />
    <Spinner
        android:id="@+id/lang_spinner"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:entries="@array/languages"
        android:layout_marginBottom="16dp" />

    <!-- Daily cap -->
    <TextView android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Daily cap (minutes)" />
    <EditText
        android:id="@+id/cap_field"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:inputType="number"
        android:layout_marginBottom="24dp" />

    <!-- Save -->
    <Button
        android:id="@+id/save_button"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="@string/settings_save" />

    <!-- IME setup instructions -->
    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="32dp"
        android:text="To enable:\nSettings → General management → Keyboard →\nOn-screen keyboards → enable Shuo\n\nThen switch keyboard via the globe icon in any text field."
        android:textColor="#666666"
        android:textSize="13sp" />

</LinearLayout>
```

- [ ] **Step 2: Add the languages array resource**

`android/app/src/main/res/values/arrays.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string-array name="languages">
        <item>zh</item>
        <item>en</item>
        <item>fr</item>
    </string-array>
</resources>
```

- [ ] **Step 3: Create `android/app/src/main/java/app/shuo/settings/SettingsActivity.kt`**

```kotlin
package app.shuo.settings

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import app.shuo.R

class SettingsActivity : AppCompatActivity() {

    private lateinit var config: ConfigStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)
        config = ConfigStore(this)

        val apiKeyField = findViewById<EditText>(R.id.api_key_field)
        val langSpinner = findViewById<Spinner>(R.id.lang_spinner)
        val capField = findViewById<EditText>(R.id.cap_field)
        val saveButton = findViewById<Button>(R.id.save_button)

        apiKeyField.setText(config.apiKey)
        capField.setText(config.dailyCapMinutes.toString())

        val langs = listOf("zh", "en", "fr")
        langSpinner.setSelection(langs.indexOf(config.defaultLanguage).coerceAtLeast(0))

        saveButton.setOnClickListener {
            config.apiKey = apiKeyField.text.toString().trim()
            config.defaultLanguage = langs[langSpinner.selectedItemPosition]
            config.dailyCapMinutes = capField.text.toString().toIntOrNull() ?: 60
            Toast.makeText(this, "Saved", Toast.LENGTH_SHORT).show()
        }

        requestMicrophonePermission()
    }

    private fun requestMicrophonePermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 1)
        }
    }
}
```

- [ ] **Step 4: Verify it compiles**

```bash
cd android && ./gradlew :app:compileDebugKotlin
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/java/app/shuo/settings/SettingsActivity.kt \
        android/app/src/main/res/layout/activity_settings.xml \
        android/app/src/main/res/values/arrays.xml
git commit -m "feat(android): add SettingsActivity"
```

---

## Task 11: Full Build and Device Smoke Test

- [ ] **Step 1: Build a debug APK**

```bash
cd android && ./gradlew assembleDebug
```

Expected: `BUILD SUCCESSFUL`. APK at `app/build/outputs/apk/debug/app-debug.apk`.

- [ ] **Step 2: Run all unit tests**

```bash
cd android && ./gradlew :app:test
```

Expected: All tests pass (≥ 16 tests).

- [ ] **Step 3: Install on device or emulator**

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

- [ ] **Step 4: Smoke test on device**

1. Open Shuo app → enter a real OpenAI API key → tap Save.
2. Go to Settings → General management → On-screen keyboards → enable Shuo.
3. Open any app with a text field (e.g. Keep, Messages).
4. Tap the text field → globe icon → select Shuo.
5. Keyboard appears → recording starts automatically (circle pulses).
6. Speak a sentence in Chinese.
7. Tap Stop.
8. Verify the transcribed text appears in the text field.
9. Verify keyboard switches back to your previous keyboard automatically.
10. Test language cycle: tap `zh` → becomes `en` → tap again → `fr` → tap → `zh`.

- [ ] **Step 5: Final commit**

```bash
git add android/
git commit -m "feat(android): Shuo Android IME — complete implementation"
```
