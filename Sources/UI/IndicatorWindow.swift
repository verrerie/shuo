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
        // Wider, shorter — fits the horizontal listening-bars + capsule.
        let panelSize = NSSize(width: 64, height: 26)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered, defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
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
            // Sit ~80pt above the screen's bottom so it floats clear of the
            // Dock and feels closer to the focused work area without covering
            // the very bottom of typical text fields.
            let bottomInset: CGFloat = 80
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
