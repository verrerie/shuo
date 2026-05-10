# Shuo Manual Smoke Checklist

Run before each release.

- [ ] Cold install on a fresh user → grant Microphone, Accessibility, Input Monitoring
- [ ] First dictation works (TextEdit, English)
- [ ] Dictate into Notes, Safari address bar, Safari `<textarea>`, Slack, Terminal, VS Code
- [ ] Multi-monitor: dot appears on the screen with the cursor
- [ ] Disconnect AirPods mid-dictation → graceful stop + "Audio device changed" notification
- [ ] Lock screen mid-dictation → no crash on wake
- [ ] 30-second dictation in each of zh / en / fr (switch via menu)
- [ ] Daily cap: temporarily set to 1 minute, exceed it, confirm dictation refuses to start
- [ ] Wait until next local-time day, confirm cap resets
- [ ] Bad API key: enter "sk-bogus", attempt dictation → notification + Preferences opens
- [ ] Reveal Log in Finder → file exists, no transcript content present
