import AppKit

final class MenuBarController: NSObject {
    private let item: NSStatusItem
    private let menu = NSMenu()
    private let onSelectLanguage: (Language) -> Void
    private let onShowPreferences: () -> Void
    private let onRevealLog: () -> Void
    private let onTogglePause: () -> Void
    private let onQuit: () -> Void

    private var currentLanguage: Language = .en
    private var paused: Bool = false

    init(
        onSelectLanguage: @escaping (Language) -> Void,
        onShowPreferences: @escaping () -> Void,
        onRevealLog: @escaping () -> Void,
        onTogglePause: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onSelectLanguage = onSelectLanguage
        self.onShowPreferences = onShowPreferences
        self.onRevealLog = onRevealLog
        self.onTogglePause = onTogglePause
        self.onQuit = onQuit
        super.init()
        item.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Shuo")
        rebuildMenu()
        item.menu = menu
    }

    func setLanguage(_ lang: Language) {
        currentLanguage = lang
        rebuildMenu()
    }

    func setListening(_ on: Bool) {
        item.button?.image = NSImage(systemSymbolName: on ? "waveform.circle.fill" : "waveform",
                                     accessibilityDescription: "Shuo")
    }

    func setCapWarning(_ on: Bool) {
        item.button?.title = on ? "•" : ""
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let langItem = NSMenuItem(title: "Language: \(currentLanguage.rawValue.uppercased())", action: nil, keyEquivalent: "")
        let langSub = NSMenu()
        for l in Language.allCases {
            let m = NSMenuItem(title: l.rawValue.uppercased(), action: #selector(selectLanguage(_:)), keyEquivalent: "")
            m.target = self
            m.representedObject = l
            m.state = (l == currentLanguage) ? .on : .off
            langSub.addItem(m)
        }
        langItem.submenu = langSub
        menu.addItem(langItem)

        menu.addItem(.separator())

        let pause = NSMenuItem(title: paused ? "Resume" : "Pause", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)

        let prefs = NSMenuItem(title: "Preferences…", action: #selector(showPrefs), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let log = NSMenuItem(title: "Reveal Log in Finder", action: #selector(revealLog), keyEquivalent: "")
        log.target = self
        menu.addItem(log)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Shuo", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let l = sender.representedObject as? Language else { return }
        onSelectLanguage(l)
    }
    @objc private func togglePause() { paused.toggle(); rebuildMenu(); onTogglePause() }
    @objc private func showPrefs() { onShowPreferences() }
    @objc private func revealLog() { onRevealLog() }
    @objc private func quit() { onQuit() }
}
