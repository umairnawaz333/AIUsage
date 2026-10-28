import Foundation

/// Connects AI Usage to Claude Code without any login.
///
/// Claude Code sends its status line command a JSON payload that includes `rate_limits`.
/// Connecting points `statusLine.command` in ~/.claude/settings.json at a small bridge script.
/// The bridge saves each payload for this app, then runs the user's original status line
/// command with the same input, so their status line looks and behaves exactly as before.
/// Their script is never modified, and Disconnect puts the original setting back.
enum ClaudeBridge {
    static let supportDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/AIUsage")
    /// One payload file per running Claude Code session.
    static let sessionsDir = supportDir.appendingPathComponent("sessions")
    static let scriptURL = supportDir.appendingPathComponent("bridge.sh")
    /// The user's original status line command, run by the bridge after saving.
    static let originalCommandURL = supportDir.appendingPathComponent("original-command")
    /// The original `statusLine` value as JSON text (empty when there was none), restored on Disconnect.
    static let originalSettingURL = supportDir.appendingPathComponent("original-statusline.json")
    static let settingsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")

    static var bridgeCommand: String { "/bin/bash \"\(scriptURL.path)\"" }

    enum BridgeError: LocalizedError {
        case unreadableSettings
        case invalidSettings

        var errorDescription: String? {
            switch self {
            case .unreadableSettings: "Couldn't read ~/.claude/settings.json."
            case .invalidSettings: "~/.claude/settings.json isn't valid JSON, so it was left unchanged."
            }
        }
    }

    static var isConnected: Bool {
        guard let settings = try? readSettings(),
              let statusLine = (try? JSONSerialization.jsonObject(with: Data(settings.utf8))) as? [String: Any],
              let line = statusLine["statusLine"] as? [String: Any] else { return false }
        return line["command"] as? String == bridgeCommand
    }

    static func connect() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        try bridgeScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let text = try readSettings()
        guard let root = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any] else {
            throw BridgeError.invalidSettings
        }
        if isConnected { return }

        // Remember what was there so the bridge can run it and Disconnect can restore it.
        let original = root["statusLine"] as? [String: Any]
        let originalCommand = original?["command"] as? String ?? ""
        try originalCommand.write(to: originalCommandURL, atomically: true, encoding: .utf8)
        let originalText = JSONEdit.valueText(forTopLevelKey: "statusLine", in: text) ?? ""
        try originalText.write(to: originalSettingURL, atomically: true, encoding: .utf8)

        // Keep the user's other statusLine options (padding, refreshInterval, …); only swap the command.
        var line = original ?? [:]
        line["type"] = "command"
        line["command"] = bridgeCommand
        try writeSettings(JSONEdit.setTopLevel("statusLine", to: try jsonText(line), in: text))
    }

    static func disconnect() throws {
        let text = try readSettings()
        if isConnected {
            let original = (try? String(contentsOf: originalSettingURL, encoding: .utf8)) ?? ""
            let updated = original.isEmpty
                ? JSONEdit.removeTopLevel("statusLine", in: text)
                : JSONEdit.setTopLevel("statusLine", to: original, in: text)
            try writeSettings(updated)
        }
        try? FileManager.default.removeItem(at: supportDir)
    }

    // MARK: - Settings file

    private static func readSettings() throws -> String {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return "{}" }
        guard let text = try? String(contentsOf: settingsURL, encoding: .utf8) else { throw BridgeError.unreadableSettings }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "{}" : text
    }

    private static func writeSettings(_ text: String) throws {
        // Never write something Claude Code can't read.
        guard (try? JSONSerialization.jsonObject(with: Data(text.utf8))) is [String: Any] else {
            throw BridgeError.invalidSettings
        }
        let fm = FileManager.default
        try fm.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: settingsURL.path) {
            let backup = settingsURL.appendingPathExtension("aiusage-backup")
            try? fm.removeItem(at: backup)
            try fm.copyItem(at: settingsURL, to: backup)
        }
        try text.write(to: settingsURL, atomically: true, encoding: .utf8)
    }

    private static func jsonText(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self)
    }

    private static let bridgeScript = """
    #!/bin/bash
    # AI Usage status line bridge, installed by AI Usage.app.
    # Saves Claude Code's status line data for AI Usage, then runs your original
    # status line command with the same input. Disconnect in AI Usage to remove it.
    dir="$HOME/Library/Application Support/AIUsage"
    input=$(cat)
    if [ -d "$dir/sessions" ]; then
      out="$dir/sessions/$PPID.json"
      printf '%s' "$input" > "$out.tmp" && mv -f "$out.tmp" "$out"
    fi
    if [ -s "$dir/original-command" ]; then
      printf '%s' "$input" | /bin/sh -c "$(cat "$dir/original-command")"
    fi

    """
}

/// Minimal edits to the top level of a JSON object that leave the rest of the file's text,
/// key order and formatting untouched.
enum JSONEdit {
    /// Replaces (or adds) a top-level key's value with `value`, which must be JSON text.
    static func setTopLevel(_ key: String, to value: String, in text: String) -> String {
        if let range = valueRange(forTopLevelKey: key, in: text) {
            return text.replacingCharacters(in: range, with: value)
        }
        guard let open = text.firstIndex(of: "{") else { return text }
        let isEmpty = text[text.index(after: open)...].first(where: { !$0.isWhitespace }) == "}"
        let entry = "\n  \"\(key)\": \(value)" + (isEmpty ? "\n" : ",")
        var result = text
        result.insert(contentsOf: entry, at: result.index(after: open))
        return result
    }

    static func removeTopLevel(_ key: String, in text: String) -> String {
        guard let member = memberRange(forTopLevelKey: key, in: text) else { return text }
        var result = text
        result.removeSubrange(member)
        return result
    }

    static func valueText(forTopLevelKey key: String, in text: String) -> String? {
        valueRange(forTopLevelKey: key, in: text).map { String(text[$0]) }
    }

    private struct Member {
        var keyStart: String.Index
        var valueRange: Range<String.Index>
    }

    private static func valueRange(forTopLevelKey key: String, in text: String) -> Range<String.Index>? {
        members(in: text).first { $0.key == key }?.member.valueRange
    }

    /// The key, its value and one neighbouring comma, so removing it leaves valid JSON.
    private static func memberRange(forTopLevelKey key: String, in text: String) -> Range<String.Index>? {
        let all = members(in: text)
        guard let i = all.firstIndex(where: { $0.key == key }) else { return nil }
        let member = all[i].member
        if i + 1 < all.count {
            return member.keyStart..<all[i + 1].member.keyStart
        }
        // Last member: also take the comma before it, if any.
        var start = member.keyStart
        var j = text.index(before: start)
        while text[j].isWhitespace, j > text.startIndex { j = text.index(before: j) }
        if text[j] == "," { start = j }
        return start..<member.valueRange.upperBound
    }

    /// Scans the top-level object and returns each member's key and where its value sits.
    private static func members(in text: String) -> [(key: String, member: Member)] {
        var result: [(String, Member)] = []
        var i = text.startIndex
        func skipSpace() { while i < text.endIndex, text[i].isWhitespace { i = text.index(after: i) } }
        func skipString() {
            i = text.index(after: i)
            while i < text.endIndex, text[i] != "\"" {
                if text[i] == "\\" { i = text.index(after: i) }
                if i < text.endIndex { i = text.index(after: i) }
            }
            if i < text.endIndex { i = text.index(after: i) }
        }
        func skipValue() {
            skipSpace()
            guard i < text.endIndex else { return }
            if text[i] == "\"" { skipString(); return }
            if text[i] == "{" || text[i] == "[" {
                var depth = 0
                while i < text.endIndex {
                    let c = text[i]
                    if c == "\"" { skipString(); continue }
                    if c == "{" || c == "[" { depth += 1 }
                    if c == "}" || c == "]" { depth -= 1 }
                    i = text.index(after: i)
                    if depth == 0 { return }
                }
                return
            }
            while i < text.endIndex, !",}]".contains(text[i]), !text[i].isWhitespace { i = text.index(after: i) }
        }

        skipSpace()
        guard i < text.endIndex, text[i] == "{" else { return [] }
        i = text.index(after: i)
        while true {
            skipSpace()
            guard i < text.endIndex, text[i] == "\"" else { break }
            let keyStart = i
            skipString()
            let key = String(text[text.index(after: keyStart)..<text.index(before: i)])
            skipSpace()
            guard i < text.endIndex, text[i] == ":" else { break }
            i = text.index(after: i)
            skipSpace()
            let valueStart = i
            skipValue()
            result.append((key, Member(keyStart: keyStart, valueRange: valueStart..<i)))
            skipSpace()
            guard i < text.endIndex, text[i] == "," else { break }
            i = text.index(after: i)
        }
        return result
    }
}
