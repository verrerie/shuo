# Shuo Android — Voice Dictation IME

**Status:** design approved 2026-05-11
**Audience:** same two users as the macOS version, on their Android devices
**Goal:** switch to the Shuo voice keyboard, speak, get the transcribed text injected into whatever input field is focused — in any app, in any of several languages.

## 1. Scope

### In scope

- Native Android app (Kotlin), distributed as an APK / Play Store release.
- IME (Input Method Editor) implementation: a pure voice keyboard with no QWERTY layout.
- Auto-start recording when the keyboard becomes active (`onStartInputView`); tap Stop to finish.
- Streaming transcription via OpenAI Realtime API, model `gpt-realtime-whisper`, same protocol as macOS version.
- Text injected via `InputConnection.commitText()` after transcription completes.
- Auto-switch back to the previous keyboard after injection via `switchToPreviousInputMethod()`.
- Language cycling zh / en / fr via a button in the keyboard UI.
- Daily soft cost cap (default 60 min/day).
- Rolling local log (no transcript content).
- Settings Activity for API key, default language, daily cap.

### Out of scope (v1)

- QWERTY layout or any typing functionality.
- Quick Settings tile or floating button triggers.
- Persistent transcription history.
- iOS or other platform clients.
- Server-side proxy for the API key.
- iCloud / cross-device settings sync.

## 2. User experience

### First run

Open the Shuo app → Settings screen with:
1. OpenAI API key field — stored in `EncryptedSharedPreferences`.
2. Default language picker — **zh / en / fr only**.
3. Daily cap field (default 60 minutes).
4. Step-by-step instructions for enabling the IME in system settings (Settings → General management → Keyboard → On-screen keyboards → Shuo).
5. Microphone permission request (runtime prompt).

### Steady state

1. User taps any text field — their normal keyboard appears.
2. User taps the globe / keyboard switcher icon → selects Shuo.
3. Shuo keyboard appears → recording starts automatically.
4. Keyboard UI shows: pulsing circle (14 dp, ~1 Hz opacity) + language label (e.g. `zh`) + Stop button.
5. User speaks.
6. User taps Stop → circle switches to a brief spinner ring (finalizing state).
7. Transcribed text is injected into the focused input field via `commitText()`.
8. Keyboard automatically switches back to the previous IME via `switchToPreviousInputMethod()`.

### Language switching

A language button in the keyboard UI cycles `zh → en → fr → zh`. A 1-second toast appears above the circle confirming the new language.

### Error handling

On any API error: stop recording, show a brief error label in the keyboard UI ("Error — check API key"), do not inject partial text. Daily cap reached: show "Daily cap reached" label, refuse to start recording.

## 3. Architecture

Six components, structurally identical to the macOS version.

```
┌─────────────────────────────────────────────────────┐
│  ShuoIME (InputMethodService)                        │
│                                                      │
│  onStartInputView() ──→ DictationController.start()  │
│  onFinishInputView() ──→ DictationController.cancel()│
│                                                      │
│  ┌──────────────┐   PCM chunks    ┌───────────────┐  │
│  │ AudioCapture │ ──────────────▶ │ RealtimeClient│  │
│  │ (AudioRecord,│                 │ (OkHttp WS,   │  │
│  │  24 kHz mono)│                 │  OpenAI RT)   │  │
│  └──────────────┘                 └───────┬───────┘  │
│                                           │ text     │
│  ┌──────────────┐  show/hide  ┌───────────▼───────┐  │
│  │ KeyboardView │◀───────────│ DictationController│  │
│  │ (pulse dot + │  commitText │ (state machine +  │  │
│  │  stop/lang)  │◀───────────│  daily cap + log)  │  │
│  └──────────────┘             └───────────────────┘  │
└─────────────────────────────────────────────────────┘

┌──────────────────────────────────────┐
│ SettingsActivity + ConfigStore        │
│ (EncryptedSharedPreferences: API key │
│  SharedPreferences: lang, cap)        │
└──────────────────────────────────────┘
```

### Components

- **ShuoIME** — `InputMethodService` subclass. `onStartInputView()` triggers `DictationController.start()`; `onFinishInputView()` triggers cancel. Hosts `KeyboardView` as the IME's input view. Reads `currentInputConnection` to call `commitText()`.
- **AudioCapture** — Wraps `AudioRecord` at 24 kHz mono PCM16. Emits ~100 ms `ByteArray` chunks as a Kotlin `Flow`. Starts/stops on demand.
- **RealtimeClient** — OkHttp `WebSocket`. One socket per dictation turn. Same message sequence as macOS version. Surfaces typed events via a `Flow<RealtimeEvent>`: `Connected`, `Delta`, `Completed(text)`, `Error(code)`, `Closed`.
- **DictationController** — State machine `idle → recording → finalizing → idle`. Coordinates `AudioCapture` and `RealtimeClient` using coroutines. Owns daily-cap counter and emits log lines. On `Completed`: calls `ShuoIME.injectText(text)` then `switchToPreviousInputMethod()`.
- **KeyboardView** — Custom `View` inflated as the IME's input view. Renders animated pulse circle, Stop button, language button, status label. Driven by `DictationController` state updates via `StateFlow`.
- **ConfigStore** — API key in `EncryptedSharedPreferences` (Jetpack Security). Language, daily cap in plain `SharedPreferences`. Loaded once into memory at IME start.

### DictationController state machine

```
idle ──[onStartInputView]──▶ recording ──[stop tapped]──▶ finalizing ──[completed]──▶ idle
  ▲                              │                              │
  └──────────────────────────────┘                             │
         [error / cancel]                              [error] └──▶ idle
```

## 4. Network protocol

Identical to macOS version:

```
[keyboard activates]
  → open WS: wss://api.openai.com/v1/realtime?intent=transcription
       headers: Authorization: Bearer <key>, OpenAI-Beta: realtime=v1
  → send transcription_session.update:
       {
         "type": "transcription_session.update",
         "session": {
           "input_audio_format": "pcm16",
           "input_audio_transcription": {
             "model": "gpt-realtime-whisper",
             "language": "<zh|en|fr>"
           },
           "turn_detection": null
         }
       }

[while recording, every ~100 ms]
  → input_audio_buffer.append { audio: <base64 pcm16> }

[stop tapped]
  → input_audio_buffer.commit
  → wait for conversation.item.input_audio_transcription.completed
  → close WS
  → commitText(transcribedText)
  → switchToPreviousInputMethod()

[errors]
  → log error, show label in KeyboardView, do NOT inject text
```

Server VAD is off (`turn_detection: null`). Deltas are ignored; only the `.completed` text is injected.

## 5. Permissions

Only two permissions required — fewer than the macOS version:

| Permission | Why | How granted |
|---|---|---|
| `RECORD_AUDIO` | Microphone access | Runtime request on first launch |
| `BIND_INPUT_METHOD` | IME registration | Granted by system automatically |

No Accessibility Service. No overlay permission. No notification permission needed.

## 6. Settings and config

### Storage

| Setting | Storage | Notes |
|---|---|---|
| `openai_api_key` | `EncryptedSharedPreferences` | Never logged |
| `default_language` | `SharedPreferences` | `zh` / `en` / `fr` |
| `daily_cap_minutes` | `SharedPreferences` | Default 60 |
| `daily_usage_seconds` | `SharedPreferences` | Reset at midnight |

On 401 from server: wipe in-memory API key, show "API key rejected — open Settings" label, refuse to start until re-entered in SettingsActivity.

### Log

`context.filesDir/shuo.log` — one line per turn, no transcript content:

```
2026-05-11T10:23:11Z | dur_ms=2410 bytes_sent=120480 lang=zh result=ok
2026-05-11T10:24:55Z | dur_ms=850 bytes_sent=42112 lang=zh result=err:401
```

## 7. Project layout

```
app/
  src/main/
    java/app/shuo/
      ime/         ShuoIME.kt, KeyboardView.kt
      audio/       AudioCapture.kt
      network/     RealtimeClient.kt, RealtimeEvent.kt
      controller/  DictationController.kt
      settings/    SettingsActivity.kt, ConfigStore.kt
    res/
      layout/      keyboard_view.xml, activity_settings.xml
      xml/         input_method.xml  (IME metadata)
    AndroidManifest.xml
  src/test/        Unit tests: state machine, protocol encoding, cap counter
build.gradle.kts
```

## 8. Out-of-scope for v1 (same as macOS)

- Persistent transcription history.
- Multi-language detection hints beyond the configured language.
- Proactive reconnect on network drop mid-session.
- Widget or Quick Settings tile trigger.
