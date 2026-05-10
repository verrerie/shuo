import AppKit

enum TextInjector {

    struct Snapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    static func snapshot(of pb: NSPasteboard = .general) -> Snapshot {
        var items: [[NSPasteboard.PasteboardType: Data]] = []
        for item in pb.pasteboardItems ?? [] {
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type] = data }
            }
            items.append(dict)
        }
        return Snapshot(items: items)
    }

    static func restore(_ snap: Snapshot, to pb: NSPasteboard = .general) {
        pb.clearContents()
        let items = snap.items.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            return item
        }
        pb.writeObjects(items)
    }

    /// Save current pasteboard, write text, post ⌘V, then restore after pasteDelay.
    static func paste(_ text: String, pasteDelay: TimeInterval = 0.12) {
        let pb = NSPasteboard.general
        let snap = snapshot(of: pb)

        pb.clearContents()
        pb.setString(text, forType: .string)

        postCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) {
            restore(snap, to: pb)
        }
    }

    private static func postCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09  // ANSI 'v'
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
