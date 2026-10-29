import Foundation
import Combine

/// Polls the payloads the Claude Code bridge saves, one file per session.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var isConnected = ClaudeBridge.isConnected
    @Published var connectionError: String?
    @Published private(set) var claudeCode = ClaudeCodeInstall.detect()
    /// A recent session made requests but sent no plan limits (Claude Code signed in with an API key).
    @Published private(set) var sawRequestsWithoutLimits = false
    /// Ticks so countdowns and "updated … ago" stay fresh between file changes.
    @Published private(set) var now = Date()

    /// Weekly limits last 7 days, so older session files can't matter any more.
    private static let maxAge: TimeInterval = 8 * 24 * 3600
    /// How recent a payload must be to say what Claude Code is doing now.
    private static let recent: TimeInterval = 3600

    private var timer: Timer?

    init() {}

    /// A fixed, connected store used to render the README images.
    init(previewSnapshot: UsageSnapshot, now: Date) {
        snapshot = previewSnapshot
        isConnected = true
        self.now = now
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        now = Date()
        isConnected = ClaudeBridge.isConnected
        claudeCode = ClaudeCodeInstall.detect()
        let sessions = readSessions()
        let merged = UsageSnapshot.merge(sessions.readings)
        if merged != snapshot { snapshot = merged }
        sawRequestsWithoutLimits = sessions.recentWithoutLimits
    }

    var status: ConnectionStatus {
        .resolve(install: claudeCode, connected: isConnected, hasUsage: snapshot != nil,
                 sawRequestsWithoutLimits: sawRequestsWithoutLimits)
    }

    func connect() {
        do {
            try ClaudeBridge.connect()
            connectionError = nil
        } catch {
            connectionError = error.localizedDescription
        }
        refresh()
    }

    func disconnect() {
        do {
            try ClaudeBridge.disconnect()
            connectionError = nil
        } catch {
            connectionError = error.localizedDescription
        }
        refresh()
    }

    /// Snapshot with any passed resets applied.
    var current: UsageSnapshot? { snapshot?.current(at: now) }

    private func readSessions() -> (readings: [Reading], recentWithoutLimits: Bool) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: ClaudeBridge.sessionsDir,
                                                      includingPropertiesForKeys: [.contentModificationDateKey])
        else { return ([], false) }

        var readings: [Reading] = []
        var recentWithoutLimits = false
        for url in files where url.pathExtension == "json" {
            guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            else { continue }
            if now.timeIntervalSince(modified) > Self.maxAge {
                try? fm.removeItem(at: url)
                continue
            }
            guard let data = try? Data(contentsOf: url) else { continue }
            if let reading = Reading(statusLine: data, savedAt: modified) {
                readings.append(reading)
            } else if now.timeIntervalSince(modified) < Self.recent, Reading.madeRequestsWithoutLimits(data) {
                recentWithoutLimits = true
            }
        }
        return (readings, recentWithoutLimits)
    }
}
