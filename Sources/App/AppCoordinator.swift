import AppKit
import AVFoundation
import SwiftUI
import IOKit.hid
import os.log

private let coordLog = OSLog(subsystem: "app.shuo", category: "coord")

@MainActor
final class AppCoordinator {
    private var config: Config
    private let configStore: ConfigStore
    private let logger: DictationLogger
    private let cap: DailyCap

    private var hotkey: HotkeyMonitor!
    private var indicator: IndicatorWindow!
    private var menuBar: MenuBarController!
    private var preferencesWindow: NSWindow?

    private var audio: AudioCapture!
    private var transport: URLSessionWebSocketTransport!
    private var realtime: RealtimeClient!
    private var dictation: DictationController!

    private var paused = false

    init() throws {
        self.configStore = ConfigStore()
        self.config = (try? configStore.load()) ?? Config()
        self.logger = DictationLogger()
        self.cap = DailyCap(limitMinutes: config.dailyCapMinutes)
    }

    func start() {
        indicator = IndicatorWindow()
        audio = AudioCapture()
        rebuildRealtime()

        dictation = DictationController(
            audio: audio,
            realtime: realtime,
            paste: LiveTextInjector(),
            indicator: indicator,
            cap: cap,
            language: { [weak self] in self?.config.defaultLanguage ?? .en },
            logger: logger
        )
        dictation.onIdleStateChange = { [weak self] idle in self?.hotkey.setIdleState(idle) }

        hotkey = HotkeyMonitor(modifier: config.hotkeyModifier) { [weak self] action in
            self?.handleHotkey(action)
        }

        menuBar = MenuBarController(
            onSelectLanguage: { [weak self] l in self?.setLanguage(l) },
            onShowPreferences: { [weak self] in self?.showPreferences() },
            onRevealLog: { NSWorkspace.shared.activateFileViewerSelecting([
                DictationLogger.defaultDirectory().appendingPathComponent("shuo.log")
            ]) },
            onTogglePause: { [weak self] in self?.togglePause() },
            onQuit: { NSApp.terminate(nil) }
        )
        menuBar.setLanguage(config.defaultLanguage)

        do { try hotkey.start() }
        catch { showPreferences(); return }

        observeSystem()
        if config.openaiApiKey.isEmpty { showPreferences() }
    }

    private func rebuildRealtime() {
        transport = URLSessionWebSocketTransport()
        realtime = RealtimeClient(transport: transport, apiKey: config.openaiApiKey)
    }

    private func handleHotkey(_ action: DoubleTapDetector.Action) {
        guard !paused, !config.openaiApiKey.isEmpty else { return }
        switch action {
        case .start:
            Task { @MainActor in
                do { try await dictation.start() }
                catch DictationError.blockedByDailyCap { notify("Daily cap reached") }
                catch { notify("Could not start: \(error.localizedDescription)") }
                refreshCapWarning()
            }
        case .stop:
            Task { @MainActor in
                do {
                    try await dictation.stop()
                } catch let e as RealtimeError where e.code == "401" || e.code.hasPrefix("ws_closed_4") {
                    handleAuthFailure()
                } catch {
                    os_log("dictation.stop threw: %{public}@", log: coordLog, type: .error,
                           String(describing: error))
                }
                refreshCapWarning()
            }
        }
    }

    private func handleAuthFailure() {
        config.openaiApiKey = ""
        try? configStore.save(config)
        notify("API key rejected — open Preferences")
        showPreferences()
    }

    private func setLanguage(_ l: Language) {
        config.defaultLanguage = l
        try? configStore.save(config)
        menuBar.setLanguage(l)
    }

    private func togglePause() {
        paused.toggle()
        menuBar.setPaused(paused)
    }

    private func refreshCapWarning() {
        switch cap.state() {
        case .warning, .blocked: menuBar.setCapWarning(true)
        case .underCap: menuBar.setCapWarning(false)
        }
    }

    private func showPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 480),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false
            )
            preferencesWindow?.title = "Shuo Preferences"
            preferencesWindow?.center()
        }
        let view = PreferencesView(
            config: Binding(get: { self.config }, set: { self.config = $0 }),
            micGranted: AudioCapture.authorizationStatus() == .authorized,
            accessibilityGranted: AXIsProcessTrusted(),
            inputMonitoringGranted: IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted,
            onRequestMic: { Task { _ = await AudioCapture.requestAuthorization() } },
            onOpenAccessibility: { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) },
            onOpenInputMonitoring: { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!) },
            onSave: { [weak self] in self?.saveAndApply() }
        )
        preferencesWindow?.contentView = NSHostingView(rootView: view)
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func saveAndApply() {
        try? configStore.save(config)
        rebuildRealtime()
        hotkey.stop()
        hotkey = HotkeyMonitor(modifier: config.hotkeyModifier) { [weak self] a in self?.handleHotkey(a) }
        try? hotkey.start()
        menuBar.setLanguage(config.defaultLanguage)
        preferencesWindow?.orderOut(nil)
    }

    private func observeSystem() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.dictation.cancel() }
        }
        nc.addObserver(forName: NSNotification.Name.AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // This notification fires not just when the user disconnects
                // a device mid-turn, but also when AVAudioEngine is created
                // and probes its input — which happens at the start of every
                // dictation. If we react during start-up we'd cancel the very
                // turn the user just initiated. Only act once we've been
                // genuinely listening for a moment.
                guard self.dictation.state == .listening,
                      let started = self.dictation.turnStartedAt,
                      Date().timeIntervalSince(started) > 1.0
                else { return }
                self.dictation.cancel()
                self.notify("Audio device changed")
            }
        }
    }

    private func notify(_ text: String) {
        let n = NSUserNotification()
        n.title = "Shuo"
        n.informativeText = text
        NSUserNotificationCenter.default.deliver(n)
    }
}
