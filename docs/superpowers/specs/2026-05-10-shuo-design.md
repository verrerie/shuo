# Shuo — Voice Dictation for macOS

**Status:** design approved 2026-05-10
**Audience:** two users (the author and his wife) on personal Macs
**Goal:** press a hotkey, speak, get the transcribed text pasted into whatever input field is focused — in any app, in any of several languages.

## 1. Scope

### In scope

- Native macOS app, single signed `.app` bundle.
- Toggle dictation via global hotkey: **double-tap Left-Option** to start, **single tap** to stop.
- Streaming transcription via OpenAI Realtime API, model `gpt-realtime-whisper`, billed at ≈ $0.017/min.
- Per-install fixed default language with a quick-switch hotkey (default ⌃⌥⇧L).
- Bottom-center floating dot as the only "listening" indicator (no caret tracking).
- Insertion via clipboard save → write transcript → simulate ⌘V → restore clipboard.
- Two separate Macs, one config each. API key stored in a plain JSON config file (Keychain deferred to a later version).
- Daily soft cost cap (default 60 min/day) and rolling local log (no transcript content).

### Out of scope (v1)

- Persistent transcription history / search.
- Multi-user profiles on a shared Mac.
- iCloud / cross-machine settings sync.
- WebRTC transport (WebSocket only).
- iOS, Windows, or Linux clients.
- Server-side proxy for the API key.

## 2. User experience

### First run

A single window with five elements:

1. OpenAI API key field → stored in `~/Library/Application Support/Shuo/config.json`.
2. Default language picker — **zh / en / fr only** in v1. Changed via the cycle hotkey or the menu.
3. Hotkey display ("Double-tap Left-Option") with a Change… button.
4. Three permission rows with status pills: Microphone, Accessibility, Input Monitoring. Each has a "Grant…" button that deep-links to the right pane of System Settings.
5. A "Test it" button that opens a tiny scratch text field and prompts the user to dictate.

### Steady state

- Menu-bar icon (`waveform` SF Symbol). Pulses while listening.
- Right- or left-click opens a menu: current language (zh / en / fr) with a submenu to switch, Pause/Resume, Preferences…, Reveal Log in Finder, Quit.
- Hotkey works system-wide.
- Bottom-center dot (14 px, soft 1 Hz opacity pulse) appears on the screen containing the mouse cursor while listening; switches to a brief spinner ring during the finalizing window between commit and the `.completed` event; hides on completion.
- Transcript is pasted into the frontmost app via simulated ⌘V; clipboard is restored ~120 ms later.
- Language-switch hotkey cycles the active language through `zh → en → fr → zh` and shows a 1-second toast above the dot.

## 3. Architecture

Five components, one stateful coordinator.

```
┌──────────────┐  start/stop  ┌──────────────┐  PCM frames   ┌──────────────────┐
│ HotkeyMonitor│─────────────▶│ DictationCtrl│──────────────▶│ AudioCapture     │
│ (CGEventTap) │              │ (state mach.)│               │ (AVAudioEngine,  │
└──────────────┘              │              │               │  24 kHz mono Int16)│
                              │              │               └──────────────────┘
┌──────────────┐  show/hide   │              │  base64 audio + commit
│ IndicatorWin │◀─────────────│              │──────────────┐
│ (NSPanel,    │              │              │              ▼
│  bottom-ctr) │              │              │       ┌──────────────────┐
└──────────────┘              │              │◀──────│ RealtimeClient   │
                              │              │  text │ (URLSession WS,  │
┌──────────────┐  paste(text) │              │       │  OpenAI realtime)│
│ TextInjector │◀─────────────│              │       └──────────────────┘
│ (clipboard+⌘V)│             └──────────────┘
└──────────────┘
                  ┌──────────────┐
                  │ Settings +   │  config.json (api key, lang, hotkey, daily cap)
                  │ MenuBarIcon  │
                  └──────────────┘
```

`DictationController` is the only stateful piece: `idle → listening → finalizing → idle`. Every other component is stateless or owns only its own resource. Each component is testable in isolation with a fake.

### Components

- **HotkeyMonitor** — session-level `CGEventTap` watching `flagsChanged` for the configured modifier keycode. Hosts a `DoubleTapDetector` that emits `start` / `stop` and a `cycleLanguage` event. Returns `nil` for the consumed event so the modifier doesn't trigger normal modifier-only behavior.
- **AudioCapture** — `AVAudioEngine` input tap at the device's native rate, converted via `AVAudioConverter` to **24 kHz mono Int16 PCM**, emitting ~100 ms chunks.
- **RealtimeClient** — `URLSessionWebSocketTask` against `wss://api.openai.com/v1/realtime?intent=transcription`. Owns one socket per dictation turn. Sends `transcription_session.update`, then `input_audio_buffer.append` per chunk, then `input_audio_buffer.commit` on stop. Surfaces typed events: `connected`, `delta` (ignored by controller in v1), `completed(text)`, `error(code)`, `closed(code)`.
- **IndicatorWindow** — borderless, click-through, `.statusBar`-level `NSPanel`. SwiftUI content. Allocated once at launch; `orderFront`/`orderOut` per turn. Repositions to bottom-center of the cursor's current screen on each show. `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`.
- **TextInjector** — pasteboard snapshot/restore around a posted ⌘V `CGEvent`. 120 ms wait between paste and restore. Snapshot covers all type identifiers present (string, RTF, image, etc.).
- **DictationController** — coordinates the four. Holds the mutable state machine. Owns the daily cap counter and the per-turn log line emission.
- **Settings + MenuBarIcon** — `NSStatusItem` host, settings window, JSON config reader/writer (`~/Library/Application Support/Shuo/config.json`, mode `0600`). Reads API key once into memory at launch.

## 4. Network protocol

### Per-turn lifecycle

```
[hotkey-on]
  → open WS to wss://api.openai.com/v1/realtime?intent=transcription
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

[while listening, every ~100 ms]
  → input_audio_buffer.append { audio: <base64 pcm16> }

[hotkey-off]
  → input_audio_buffer.commit
  → wait for conversation.item.input_audio_transcription.completed
  → close WS

[errors]
  → any "error" event → log, hide indicator, surface a one-shot menubar
    notification, do NOT paste partial text
```

### Design choices

- **Fresh WebSocket per turn**, not a long-lived connection. Simpler state, no idle keepalive, no reconnection logic. WS open over a warm TLS session is ~150–300 ms — acceptable for first-paste latency. Revisit if user feedback says otherwise.
- **Server VAD off** (`turn_detection: null`). Toggle mode means the user controls start/stop; we send `commit` on stop and read the `.completed` event for the final text.
- **Deltas ignored.** `…transcription.delta` events arrive but are not pasted. Only the `.completed` text reaches the user. This avoids correction-jitter in the target app and the partial-paste failure mode where a connection drop leaves half a sentence behind.

## 5. Hotkey, indicator, paste

### Double-tap detection

```
on left-⌥ press:
   if (now - lastReleaseAt) < 400ms AND state == idle:
       → fire "start"
   else if state == listening:
       → fire "stop"
   record press time
on left-⌥ release:
   record release time
```

The 400 ms window is configurable in code (not exposed in UI in v1). The monitored modifier (default Left-Option) is exposed in Preferences for either user to remap.

### Indicator window

- `NSPanel`, `styleMask = .borderless`
- `level = .statusBar`
- `isOpaque = false`, `backgroundColor = .clear`
- `ignoresMouseEvents = true`
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`
- Position: bottom-center of `NSScreen` containing `NSEvent.mouseLocation` at show time, with a small bottom inset above the Dock when visible.
- Content: 14 px circle, opacity 0.6 ↔ 1.0 at ~1 Hz while listening, brief ring spinner during `finalizing`. No text.

### Paste sequence

```
1. snapshot = NSPasteboard.general types + data per type + changeCount
2. clear pasteboard, write transcript as .string
3. post ⌘V via CGEvent (cmd-down, v-down, v-up, cmd-up) to the
   currently-frontmost app
4. wait ~120 ms
5. restore the snapshot
```

### Accepted limitations

- **No focused text field** in the frontmost app: ⌘V is a no-op or triggers an error sound. We cannot reliably detect this across browsers / Electron / terminals. Accepted; menubar icon flashes once to confirm transcription succeeded; clipboard still holds text briefly so the user can manually ⌘V.
- **App grabs ⌘V for something else** (rare): same outcome, accepted for v1.

## 6. Settings, permissions, API key

### Permissions required

- **Microphone** — `AVCaptureDevice.requestAccess(for: .audio)`.
- **Accessibility** — `AXIsProcessTrustedWithOptions`. Required to post the ⌘V `CGEvent`.
- **Input Monitoring** — `IOHIDCheckAccess(.keyboard)`. Required for the global `CGEventTap` to see modifier keys.

Each is shown in Preferences with a status pill and a deep-link button to the relevant System Settings pane.

### API key and config storage

- Stored in `~/Library/Application Support/Shuo/config.json` along with the rest of the user's settings (default language, hotkey modifier, daily cap).
- File is created with mode `0600` (readable only by the owning user).
- Loaded once into memory at launch.
- Sent as `Authorization: Bearer <key>` on every WebSocket open.
- On 401 from the server: wipe the in-memory copy, surface a notification ("API key rejected — open Preferences"), refuse to start dictation until re-entered. The on-disk value is not auto-cleared (the user re-saves from Preferences).
- Never logged.

Example config file:

```json
{
  "openai_api_key": "sk-...",
  "default_language": "fr",
  "hotkey_modifier": "left_option",
  "daily_cap_minutes": 60
}
```

### Trust model

API key lives client-side in a plain file on each user's personal Mac, readable only by that user. Same trust model as anyone using the OpenAI Playground. A backend proxy is not justified for two trusted users. Moving the key into Keychain is listed under future work.

## 7. Errors and edge cases

| Failure | Detection | Response |
|---|---|---|
| No mic permission | `AVCaptureDevice.authorizationStatus` ≠ `.authorized` at start | Indicator red flash; notification with "Open System Settings" deep-link |
| Network down / DNS fail | WS open errors within 3 s | Red flash; notification "No connection" |
| 401 from OpenAI | WS closes with 401 right after open | Wipe in-memory key; notification; disable hotkey until re-entered |
| 429 rate limit | error event `rate_limit_exceeded` | Notification with retry-after; user retries |
| WS closes mid-stream | `didCloseWith:` while `state == listening` | Stop capture; hide indicator; no paste; notification "Connection dropped" |
| Empty transcript | `.completed` with `text == ""` after trim | No paste; indicator two-blink before hide |
| Paste with no focused field | Cannot reliably detect | Accepted; clipboard holds text briefly so user can ⌘V manually |
| User toggles off before any audio sent | `state == listening`, 0 frames committed | Cancel WS without `commit`; no notification |
| Multi-display / Spaces | `NSPanel` repositions on cursor's screen at show; `.canJoinAllSpaces` | — |
| System sleep mid-dictation | `NSWorkspace.willSleepNotification` | Force-stop |
| Audio device change mid-dictation | `AVAudioEngineConfigurationChange` notification | Force-stop; notification "Audio device changed" |

### Cost guardrail

A daily soft cap (default 60 minutes, configurable). Tracked locally in `UserDefaults`. At 80% the menubar icon shows a yellow dot; at 100% dictation refuses to start until the next local-time day. Defends against the toggle-mode "left the mic on" failure and against runaway WS loops.

### Observability

Rolling log file at `~/Library/Logs/Shuo/shuo.log`, 5 MB ring. One line per turn:

```
2026-05-10T14:23:11Z | dur_ms=2410 bytes_sent=120480 lang=fr result=ok
2026-05-10T14:24:55Z | dur_ms=850 bytes_sent=42112 lang=zh result=err:rate_limit_exceeded
```

No transcript content is logged. Menu has "Reveal Log in Finder" so the user can attach the file when reporting an issue.

## 8. Testing

### Unit (XCTest, no AppKit)

- `DictationController` driven through every state transition with fake `AudioCapture` and `RealtimeClient`.
- `DoubleTapDetector` fed synthetic press/release timestamps. Covers window edges (399 ms, 401 ms), interleaved presses, modifier-stuck scenarios.
- `RealtimeClient` against a `URLProtocol`-based fake WebSocket replaying canned event sequences: happy, 401, rate-limit, mid-stream close, empty completion.
- `TextInjector` pasteboard snapshot/restore round-trip across `.string`, `.rtf`, `.png`, and multi-type clipboards.

### Integration (no real OpenAI calls)

- Full pipeline with a fake audio source feeding pre-recorded PCM and a fake WS replaying transcripts. Asserts the right text lands on the pasteboard before restore.
- Permission-denied paths: mock `AVCaptureDevice.authorizationStatus` returning `.denied`; assert no WS opened.

### Manual smoke checklist (one page, run before each release)

- Cold start → grant all 3 permissions → first dictation works.
- Dictate into: Notes, Safari address bar, Safari `<textarea>`, Slack, Terminal, VS Code.
- Multi-monitor: dot appears on the screen with the cursor.
- AirPods disconnect mid-dictation → graceful stop.
- Lock screen mid-dictation → no crash on wake.
- 30-second dictation in each of zh / en / fr.
- Daily cap: temporarily set to 1 minute; confirm it triggers and lifts at midnight.

### Explicitly not tested in CI

- End-to-end against the real OpenAI endpoint. Too slow, too flaky, costs money. The fake-WS integration tests cover protocol shape; the manual checklist covers the real network path before a release.

## 9. Open questions / future work

- Move the API key from the JSON config file into macOS Keychain.
- Persistent connection (one WS, many turns) if first-paste latency proves bothersome.
- AX-based insertion fallback for native Cocoa fields, with paste as the universal fallback.
- Optional auto-stop after N seconds of silence as a safety net layered on top of toggle mode.
- Add more languages once we know we want them.
- Translation mode (transcribe in language X, paste in language Y).
