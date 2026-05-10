import AppKit
import Carbon.HIToolbox

/// Watches modifier-flag changes for a configured keycode and emits start/stop actions.
/// Right-Option keycode = 61 (kVK_RightOption); Left-Option keycode = 58 (kVK_Option).
final class HotkeyMonitor {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var detector: DoubleTapDetector
    private let keycode: Int64
    private let onAction: (DoubleTapDetector.Action) -> Void

    /// External setter so DictationController can keep the detector's idle flag in sync.
    func setIdleState(_ idle: Bool) { detector.idleState = idle }

    init(modifier: HotkeyModifier, onAction: @escaping (DoubleTapDetector.Action) -> Void) {
        self.detector = DoubleTapDetector(windowSeconds: 0.4)
        self.detector.idleState = true
        self.keycode = (modifier == .leftOption) ? Int64(kVK_Option) : Int64(kVK_RightOption)
        self.onAction = onAction
    }

    func start() throws {
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard type == .flagsChanged, let refcon else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                me.handle(event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: opaqueSelf
        ) else {
            throw NSError(domain: "HotkeyMonitor", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not create event tap (Input Monitoring permission missing?)"
            ])
        }
        let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = src
    }

    func stop() {
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        runLoopSource = nil
        tap = nil
    }

    private func handle(event: CGEvent) {
        guard event.getIntegerValueField(.keyboardEventKeycode) == keycode else { return }
        let now = ProcessInfo.processInfo.systemUptime
        // Check the Option-mask bit specifically — using `flags.rawValue != 0`
        // confuses other modifiers (Caps Lock, Shift) for an Option press.
        let isPressed = event.flags.contains(.maskAlternate)
        let action = isPressed ? detector.onPress(at: now) : detector.onRelease(at: now)
        if let action {
            DispatchQueue.main.async { self.onAction(action) }
        }
    }
}
