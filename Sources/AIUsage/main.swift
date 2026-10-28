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

// `AIUsage --disconnect` restores the user's original status line without opening the app.
// Homebrew's `uninstall --zap` runs it before deleting the bridge files.
if CommandLine.arguments.contains("--disconnect") {
    do {
        try ClaudeBridge.disconnect()
        print("AI Usage disconnected from Claude Code.")
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("AI Usage: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
