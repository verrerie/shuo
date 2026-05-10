import AppKit
import SwiftUI

final class IndicatorWindow {
    private let panel: NSPanel
    private let hosting: NSHostingView<AnyView>

    init() {
        hosting = NSHostingView(rootView: AnyView(IndicatorView(state: .listening)))
        let panelSize = NSSize(width: 64, height: 26)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isMovable = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.tabbingMode = .disallowed
        panel.contentView = hosting
        hosting.frame = NSRect(origin: .zero, size: panelSize)

        // macOS 26's NSWMWindowCoordinator crashes the second time a panel is
        // ordered front — orderOut clears its screen affinity and the next
        // orderFrontRegardless trips an assertion in clearDisplayAffinityForWindow.
        // So order-front exactly once here and use alphaValue for show/hide.
        panel.alphaValue = 0
        if let screen = NSScreen.main {
            // Anchor to screen.frame (not visibleFrame) so the indicator hugs
            // the absolute bottom edge — visibleFrame stops above the Dock.
            // Floating + ignoresMouseEvents means we overlay the Dock harmlessly.
            let bottomInset: CGFloat = 2
            panel.setFrameOrigin(NSPoint(x: screen.frame.midX - panelSize.width / 2,
                                         y: screen.frame.minY + bottomInset))
        }
        panel.orderFrontRegardless()
    }

    func show(state: IndicatorState) {
        setState(state)
        panel.alphaValue = 1
    }

    func hide() {
        panel.alphaValue = 0
    }

    func setState(_ state: IndicatorState) {
        hosting.rootView = AnyView(IndicatorView(state: state))
    }
}
