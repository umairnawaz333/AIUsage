import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private lazy var notch = NotchController(store: store)
    private lazy var settings = SettingsWindowController(store: store)

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()
        notch.model.onOpenSettings = { [weak self] in
            self?.notch.collapse()
            self?.settings.show()
        }
        notch.model.onQuit = { NSApp.terminate(nil) }
        notch.show()
        // First run (or after Disconnect): show Settings so the user can connect Claude.
        if !store.isConnected { settings.show() }
    }

    /// Opening the app again (e.g. from Finder) shows Settings, since there is no Dock icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings.show()
        return false
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
