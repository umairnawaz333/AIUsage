import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let store: UsageStore
    private var window: NSWindow?

    init(store: UsageStore) {
        self.store = store
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable],
                                  backing: .buffered, defer: false)
            window.title = "AI Usage Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(store: store))
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @AppStorage(SettingsKey.wingStyle) private var styleRaw = WingStyle.concentric.rawValue
    @AppStorage(SettingsKey.showIcon) private var showIcon = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notch style").font(.headline)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(WingStyle.allCases) { style in
                    StyleCard(style: style, snapshot: store.current, showIcon: showIcon,
                              selected: style.rawValue == styleRaw)
                        .onTapGesture { styleRaw = style.rawValue }
                }
            }

            Toggle("Show Claude icon", isOn: $showIcon)
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Usage comes from ~/.claude/usage-now.txt, which your Claude Code status line updates while Claude Code is running.")
                if let snap = store.snapshot {
                    Text("Last updated \(UsageFormat.age(of: snap.savedAt, from: store.now)).")
                } else {
                    Text("No usage data found yet.")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(Self.versionString).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit AI Usage") { NSApp.terminate(nil) }
            }
        }
        .padding(20)
        .frame(width: 600)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't change launch at login: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    /// Read from the installed bundle so the version has one source of truth (the VERSION file).
    static var versionString: String {
        let info = Bundle.main.infoDictionary
        guard let version = info?["CFBundleShortVersionString"] as? String else { return "Development build" }
        let build = info?["CFBundleVersion"] as? String
        return "Version \(version)" + (build.map { " (\($0))" } ?? "")
    }
}

private struct StyleCard: View {
    var style: WingStyle
    var snapshot: UsageSnapshot?
    var showIcon: Bool
    var selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .trailing) {
                LinearGradient(colors: [Color(red: 0.11, green: 0.17, blue: 0.39), Color(red: 0.42, green: 0.19, blue: 0.58)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14, style: .continuous)
                    .fill(.black)
                    .frame(height: 46)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.trailing, 10)
                WingView(style: style, snapshot: snapshot, showIcon: showIcon)
                    .scaleEffect(1.8, anchor: .trailing)
                    .frame(height: 46)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.trailing, 20)
            }
            .frame(height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 5) {
                Text(style.letter).foregroundStyle(.secondary)
                Text(style.title).fontWeight(.semibold)
            }
            .font(.system(size: 11))
            Text(style.note).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: selected ? 2 : 1))
        .contentShape(Rectangle())
    }
}
