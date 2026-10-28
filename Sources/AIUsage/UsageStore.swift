import Foundation
import Combine

/// Polls the usage file the Claude Code status line keeps up to date.
@MainActor
final class UsageStore: ObservableObject {
    static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/usage-now.txt")

    @Published private(set) var snapshot: UsageSnapshot?
    /// Ticks so countdowns and "updated … ago" stay fresh between file changes.
    @Published private(set) var now = Date()

    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        now = Date()
        guard let text = try? String(contentsOf: Self.fileURL, encoding: .utf8),
              let parsed = UsageSnapshot.parse(text) else { return }
        if parsed != snapshot { snapshot = parsed }
    }

    /// Snapshot with any passed resets applied.
    var current: UsageSnapshot? { snapshot?.current(at: now) }
}
