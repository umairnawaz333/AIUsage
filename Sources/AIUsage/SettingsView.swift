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
        // The app has no Dock icon and is rarely active, so force Settings in front of other apps' windows.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
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
            ClaudeConnectionSection(store: store)

            Divider()

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

struct StyleCard: View {
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

/// Connect / Disconnect Claude Code, with what it does in plain words.
private struct ClaudeConnectionSection: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        let status = store.status
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ClaudeMark(size: 14)
                Text("Claude").font(.headline)
                Spacer()
                badge(status)
                buttons(status)
            }

            Text(explanation(status))
                .font(.caption)
                .foregroundStyle(status == .noPlanLimits ? Color.orange : .secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let error = store.connectionError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder private func badge(_ status: ConnectionStatus) -> some View {
        switch status {
        case .claudeCodeMissing:
            Label("Claude Code not found", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange).font(.callout)
        case .notConnected:
            Label("Claude Code found", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary).font(.callout)
        case .noPlanLimits:
            Label("No plan limits", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange).font(.callout)
        case .waiting, .ok:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.callout)
        }
    }

    @ViewBuilder private func buttons(_ status: ConnectionStatus) -> some View {
        if status == .claudeCodeMissing {
            Button("Install Claude Code") { NSWorkspace.shared.open(ClaudeCodeInstall.setupURL) }
        }
        if store.isConnected {
            Button("Disconnect") { store.disconnect() }
        } else {
            // Nothing is changed on the Mac until Claude Code is there to use the connection.
            Button("Connect") { store.connect() }
                .buttonStyle(.borderedProminent)
                .disabled(status == .claudeCodeMissing)
        }
    }

    private func explanation(_ status: ConnectionStatus) -> String {
        let openOnce = "Open Claude Code once and sign in with your Claude account."
        switch status {
        case .claudeCodeMissing where store.snapshot != nil:
            return "Claude Code isn't on this Mac any more, so these are the last numbers it reported. Reinstall it to keep them up to date."
        case .claudeCodeMissing:
            return "AI Usage reads your plan limits from Claude Code, Anthropic's coding tool. Install it and sign in with a Claude Pro or Max plan, then come back here to connect. This page updates by itself."
        case .notConnected(let neverOpened):
            return "AI Usage reads your limits from Claude Code on this Mac. No password, and nothing leaves your computer. Connecting adds a small bridge in front of your Claude Code status line; if you already have one, it keeps working exactly as before."
                + (neverOpened ? " " + openOnce : "")
        case .waiting(let neverOpened):
            return neverOpened ? openOnce + " Then send a message and your numbers will appear."
                : "Waiting for numbers. Open Claude Code and send a message, and they'll appear."
        case .noPlanLimits:
            return "Claude Code is running, but it isn't reporting plan limits. Only Claude Pro and Max plans have 5-hour and weekly limits. If you're signed in with an API key, run /login in Claude Code and choose your Claude account."
        case .ok:
            let age = store.snapshot.map { UsageFormat.age(of: $0.savedAt, from: store.now) } ?? ""
            return "Last update \(age). Numbers refresh while Claude Code is running."
        }
    }
}
