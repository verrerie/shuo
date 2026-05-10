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
        do {
            let c = try AppCoordinator()
            coordinator = c
            c.start()
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
