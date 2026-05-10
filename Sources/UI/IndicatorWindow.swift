import AppKit
import SwiftUI

final class IndicatorWindow {
    private let panel: NSPanel
    private let hosting: NSHostingView<AnyView>
    private var currentState: IndicatorState = .listening

    init() {
        hosting = NSHostingView(rootView: AnyView(IndicatorView(state: .listening)))
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 60, height: 30),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = hosting
        hosting.frame = NSRect(x: 0, y: 0, width: 60, height: 30)
    }

    func show(state: IndicatorState) {
        currentState = state
        hosting.rootView = AnyView(IndicatorView(state: state))
        // Order on-screen first so the panel has a screen affinity before any
        // frame mutation. Calling setFrame(..., display:true) on a panel that
        // has never been displayed crashes inside NSWMWindowCoordinator on
        // macOS 26 (the affinity-clear path tries to read state that doesn't
        // exist yet).
        panel.orderFrontRegardless()
        positionAtCursorScreen()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func setState(_ state: IndicatorState) {
        currentState = state
        hosting.rootView = AnyView(IndicatorView(state: state))
    }

    private func positionAtCursorScreen() {
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main!
        let frame = panel.frame
        let bottomInset: CGFloat = 24
        let x = screen.frame.midX - frame.width / 2
        let y = screen.visibleFrame.minY + bottomInset
        // setFrameOrigin avoids the resize path inside NSWMWindowCoordinator
        // that crashes on macOS 26; size never changes after init anyway.
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
