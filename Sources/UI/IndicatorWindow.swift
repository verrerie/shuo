import AppKit
import SwiftUI

final class IndicatorWindow {
    private let panel: NSPanel
    private let hosting: NSHostingView<AnyView>
    private var currentState: IndicatorState = .listening

    init() {
        hosting = NSHostingView(rootView: AnyView(IndicatorView(state: .listening)))
        // Conventional HUD panel: use the proper utility/hud style instead of
        // borderless+statusBar. macOS 26's NSWMWindowCoordinator crashes when
        // making a `.borderless` `NSPanel` at `.statusBar` level visible.
        // Borderless: no titlebar chrome over the indicator content. This was
        // originally avoided because of an NSWMWindowCoordinator crash on
        // macOS 26 when ordering a borderless panel front, but that crash
        // only fired when we orderOut/orderFront-cycled on each show.
        // We now order-front exactly once during init and toggle alphaValue
        // for show/hide, which leaves screen affinity untouched and is safe.
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

        // Order the panel on-screen ONCE here. Subsequent show()/hide() calls
        // toggle alphaValue instead of orderOut/orderFront. Reason: macOS 26's
        // NSWMWindowCoordinator crashes the second time a panel is ordered
        // front — orderOut clears its screen affinity, and the next
        // orderFrontRegardless trips an assertion in clearDisplayAffinityForWindow.
        panel.alphaValue = 0
        if let screen = NSScreen.main {
            // Hug the bottom edge of the screen's usable area (just above the
            // Dock if it's shown; at the very bottom if it auto-hides).
            let bottomInset: CGFloat = 2
            panel.setFrameOrigin(NSPoint(x: screen.frame.midX - panelSize.width / 2,
                                         y: screen.visibleFrame.minY + bottomInset))
        }
        panel.orderFrontRegardless()
    }

    func show(state: IndicatorState) {
        currentState = state
        hosting.rootView = AnyView(IndicatorView(state: state))
        panel.alphaValue = 1
    }

    func hide() {
        panel.alphaValue = 0
    }

    func setState(_ state: IndicatorState) {
        currentState = state
        hosting.rootView = AnyView(IndicatorView(state: state))
    }
}
