import SwiftUI
import AppKit

@main
struct ShuoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable automatic window tabbing globally — combined with our
        // borderless indicator panel it triggers an NSWMWindowCoordinator
        // crash on macOS 26.
        NSWindow.allowsAutomaticWindowTabbing = false

        do {
            let c = try AppCoordinator()
            coordinator = c
            c.start()
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
