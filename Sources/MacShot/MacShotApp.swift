import SwiftUI

@main
struct MacShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        PermissionManager.shared.requestScreenCapturePermission()

        menuBarManager = MenuBarManager(appState: appState)
        menuBarManager?.setup()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
