import Foundation

/// Whether Claude Code is on this Mac.
enum ClaudeCodeInstall: Equatable {
    case notFound
    /// The `claude` program exists but has never run, so there's no ~/.claude folder yet.
    case neverOpened
    case ready

    static let setupURL = URL(string: "https://code.claude.com/docs/en/setup")!

    static func detect(fileManager fm: FileManager = .default) -> ClaudeCodeInstall {
        let home = fm.homeDirectoryForCurrentUser
        if fm.fileExists(atPath: home.appendingPathComponent(".claude").path) { return .ready }
        return programPaths(home: home, fileManager: fm).contains(where: fm.isExecutableFile(atPath:))
            ? .neverOpened : .notFound
    }

    /// Where the official installer, Homebrew, npm and common Node version managers put `claude`.
    static func programPaths(home: URL, fileManager fm: FileManager) -> [String] {
        var paths = [".local/bin/claude", ".npm-global/bin/claude", ".bun/bin/claude", ".volta/bin/claude"]
            .map { home.appendingPathComponent($0).path }
        paths += ["/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        let nvm = home.appendingPathComponent(".nvm/versions/node")
        if let versions = try? fm.contentsOfDirectory(atPath: nvm.path) {
            paths += versions.map { nvm.appendingPathComponent("\($0)/bin/claude").path }
        }
        return paths
    }
}

/// What the app tells the user about its connection, most blocking first.
enum ConnectionStatus: Equatable {
    case claudeCodeMissing
    case notConnected(neverOpened: Bool)
    case waiting(neverOpened: Bool)
    /// Claude Code is making requests but reports no plan limits (signed in with an API key).
    case noPlanLimits
    case ok

    static func resolve(install: ClaudeCodeInstall, connected: Bool, hasUsage: Bool,
                        sawRequestsWithoutLimits: Bool) -> ConnectionStatus {
        if install == .notFound { return .claudeCodeMissing }
        if !connected { return .notConnected(neverOpened: install == .neverOpened) }
        if hasUsage { return .ok }
        if sawRequestsWithoutLimits { return .noPlanLimits }
        return .waiting(neverOpened: install == .neverOpened)
    }
}

extension Reading {
    /// True for a payload from a session that has already talked to Anthropic but carries no plan limits.
    /// A brand-new session has no limits yet either, so it only counts once requests have been made.
    static func madeRequestsWithoutLimits(_ data: Data) -> Bool {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              Reading(statusLine: data, savedAt: .now) == nil else { return false }
        let apiTime = ((root["cost"] as? [String: Any])?["total_api_duration_ms"] as? NSNumber)?.doubleValue ?? 0
        let inputTokens = ((root["context_window"] as? [String: Any])?["total_input_tokens"] as? NSNumber)?.doubleValue ?? 0
        return apiTime > 0 || inputTokens > 0
    }
}
