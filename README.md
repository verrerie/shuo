# Shuo

Voice dictation for macOS, powered by OpenAI's `gpt-realtime-whisper`.
Double-tap Left-Option, speak, single-tap to stop. The transcript is pasted into whatever app is focused.

## Requirements

- macOS 13 (Ventura) or later
- An OpenAI API key with access to the realtime transcription beta
- [xcodegen](https://github.com/yonaskolb/XcodeGen) for development (`brew install xcodegen`)

## Build (development)

```
xcodegen generate
open Shuo.xcodeproj
```

Build & run from Xcode. The first launch prompts for Microphone, Accessibility, and Input Monitoring permissions in System Settings.

## Build (release)

```
./Scripts/build-release.sh
```

Outputs `build/export/Shuo.app`.

## Configuration

Settings live in `~/Library/Application Support/Shuo/config.json` (mode `0600`). Manage them through the menu-bar Preferences pane.

## Logs

`~/Library/Logs/Shuo/shuo.log` — one line per turn, no transcript content.
