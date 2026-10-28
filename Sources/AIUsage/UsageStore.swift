import Foundation
import Combine

/// Polls the payloads the Claude Code bridge saves, one file per session.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var isConnected = ClaudeBridge.isConnected
    @Published var connectionError: String?
    /// Ticks so countdowns and "updated … ago" stay fresh between file changes.
    @Published private(set) var now = Date()

    /// Weekly limits last 7 days, so older session files can't matter any more.
    private static let maxAge: TimeInterval = 8 * 24 * 3600

    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        now = Date()
        isConnected = ClaudeBridge.isConnected
        let merged = UsageSnapshot.merge(readSessions())
        if merged != snapshot { snapshot = merged }
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

    private func readSessions() -> [Reading] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: ClaudeBridge.sessionsDir,
                                                      includingPropertiesForKeys: [.contentModificationDateKey])
        else { return [] }

        return files.compactMap { url in
            guard url.pathExtension == "json",
                  let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            else { return nil }
            if now.timeIntervalSince(modified) > Self.maxAge {
                try? fm.removeItem(at: url)
                return nil
            }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return Reading(statusLine: data, savedAt: modified)
        }
    }
}
