# Shuo

Voice dictation for macOS, powered by OpenAI's `gpt-realtime-whisper` (≈ $0.017 / min).

**Double-tap Left-Option, speak, single-tap to stop.** The transcript is pasted into whatever text field is focused — Notes, Slack, Safari, Terminal, anything that accepts ⌘V.

A small horizontal indicator at the bottom of the screen pulses while listening.

## Requirements

- macOS 13 (Ventura) or later
- An OpenAI API key
- [xcodegen](https://github.com/yonaskolb/XcodeGen) for development (`brew install xcodegen`)

## Build & install (debug — recommended for personal use)

```
./Scripts/install-debug.sh
open /Applications/Shuo.app
```

The script regenerates the Xcode project, builds, and copies `Shuo.app` to `/Applications/`. Installing to a stable path means macOS Privacy grants survive subsequent rebuilds.

On first launch you'll be prompted to grant three permissions in System Settings → Privacy & Security:

- **Microphone** — to record audio
- **Accessibility** — to post the ⌘V paste keystroke
- **Input Monitoring** — for the global hotkey

Then open Preferences from the menu-bar icon, paste your OpenAI API key, pick a default language (`zh`, `en`, or `fr`), and Save.

## Build (release archive)

```
./Scripts/build-release.sh
```

Outputs `build/export/Shuo.app`.

## Usage

- **Double-tap Left-Option** to start listening. The indicator appears at the bottom of the screen.
- **Single-tap Left-Option** to stop. The transcript is pasted into the focused field.
- The menu-bar icon lets you switch language (`zh / en / fr`), pause, open Preferences, reveal the log, or quit.

The configured `language` is a hint — `gpt-realtime-whisper` auto-detects in practice, so you can speak Chinese with the language set to English and still get correct Chinese output.

## Configuration

Settings live in `~/Library/Application Support/Shuo/config.json` (mode `0600`):

```json
{
  "openai_api_key": "sk-...",
  "default_language": "en",
  "hotkey_modifier": "left_option",
  "daily_cap_minutes": 60
}
```

A daily soft cap (default 60 minutes) prevents runaway bills. The menu-bar icon shows a yellow dot at 80% and dictation refuses to start once the cap is reached.

## Logs

`~/Library/Logs/Shuo/shuo.log` — one line per turn, **no transcript content**:

```
2026-05-10T14:23:11Z | dur_ms=2410 bytes_sent=120480 lang=en result=ok
2026-05-10T14:24:55Z | dur_ms=850 bytes_sent=42112 lang=zh result=err:rate_limit_exceeded
```

For deeper debugging:

```
log show --predicate 'subsystem == "app.shuo"' --last 5m --style compact --info
```

## Project layout

- `Sources/App/` — `@main` entry, app coordinator (wires components, handles system notifications)
- `Sources/Audio/` — mic capture (`AVAudioEngine`) and PCM converter to 24 kHz mono Int16
- `Sources/Network/` — OpenAI Realtime WebSocket client + protocol Codables
- `Sources/Hotkey/` — global `CGEventTap` and the double-tap detector (pure logic)
- `Sources/Controller/` — `DictationController` state machine, daily-cap counter
- `Sources/UI/` — menu-bar icon, indicator panel, preferences view
- `Sources/System/` — JSON config store, clipboard / paste injector, rolling log
- `Tests/` — XCTest target. 33 tests covering protocol encoding, state machine, double-tap edge cases, etc.
- `Scripts/install-debug.sh` — one-shot rebuild + install to `/Applications/Shuo.app`
- `Scripts/build-release.sh` — archive + export
- `docs/superpowers/specs/` — design spec
- `docs/superpowers/plans/` — implementation plan
- `docs/smoke-checklist.md` — manual smoke test before each release

## Tests

```
xcodegen generate
xcodebuild -project Shuo.xcodeproj -scheme Shuo -destination 'platform=macOS' test
```

CI is not set up — tests run locally.

## License

MIT — see `LICENSE`.
