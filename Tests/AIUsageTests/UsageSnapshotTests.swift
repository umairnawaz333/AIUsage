import Foundation
import Testing
@testable import AIUsage

struct ReadingTests {
    private func payload(_ json: String) -> Data { Data(json.utf8) }

    @Test func readsRateLimitsFromStatusLinePayload() throws {
        let json = """
        {"session_id":"abc","model":{"id":"x"},"rate_limits":{
          "five_hour":{"used_percentage":26.6,"resets_at":1793202600},
          "seven_day":{"used_percentage":41,"resets_at":"1793286000"}}}
        """
        let reading = try #require(Reading(statusLine: payload(json), savedAt: Date(timeIntervalSince1970: 5)))
        #expect(reading.session == .init(percent: 27, resetsAt: Date(timeIntervalSince1970: 1793202600)))
        #expect(reading.weekly == .init(percent: 41, resetsAt: Date(timeIntervalSince1970: 1793286000)))
    }

    @Test func acceptsISODatesAndClamps() throws {
        let json = #"{"rate_limits":{"five_hour":{"used_percentage":140,"resets_at":"2026-10-28T15:50:00Z"}}}"#
        let reading = try #require(Reading(statusLine: payload(json), savedAt: .now))
        #expect(reading.session?.percent == 100)
        #expect(reading.session?.resetsAt == ISO8601DateFormatter().date(from: "2026-10-28T15:50:00Z"))
        #expect(reading.weekly == nil)
    }

    @Test func rejectsPayloadsWithoutLimits() {
        #expect(Reading(statusLine: payload(#"{"model":{"id":"x"}}"#), savedAt: .now) == nil)
        #expect(Reading(statusLine: payload(#"{"rate_limits":{}}"#), savedAt: .now) == nil)
        #expect(Reading(statusLine: payload("not json"), savedAt: .now) == nil)
    }
}

struct MergeTests {
    private func limit(_ percent: Int, _ reset: TimeInterval?) -> UsageSnapshot.Limit {
        .init(percent: percent, resetsAt: reset.map { Date(timeIntervalSince1970: $0) })
    }

    @Test func idleSessionsDoNotLowerTheNumbers() throws {
        let busy = Reading(savedAt: Date(timeIntervalSince1970: 10), session: limit(30, 1000), weekly: limit(41, 5000))
        let idle = Reading(savedAt: Date(timeIntervalSince1970: 20), session: limit(12, 1000), weekly: limit(40, 5000))
        let snap = try #require(UsageSnapshot.merge([busy, idle]))
        #expect(snap.session.percent == 30)
        #expect(snap.weekly.percent == 41)
        #expect(snap.savedAt == Date(timeIntervalSince1970: 20))
    }

    @Test func newerWindowWinsEvenIfLower() throws {
        let old = Reading(savedAt: .now, session: limit(95, 1000), weekly: nil)
        let new = Reading(savedAt: .now, session: limit(3, 19000), weekly: nil)
        let snap = try #require(UsageSnapshot.merge([old, new]))
        #expect(snap.session == limit(3, 19000))
    }

    @Test func keepsWhicheverLimitIsAvailable() throws {
        let onlyWeekly = Reading(savedAt: .now, session: nil, weekly: limit(41, 5000))
        let snap = try #require(UsageSnapshot.merge([onlyWeekly]))
        #expect(snap.weekly.percent == 41)
        #expect(snap.session == limit(0, nil))
        #expect(UsageSnapshot.merge([]) == nil)
    }

    @Test func passedResetDropsToZero() {
        let snap = UsageSnapshot(savedAt: .now, session: limit(80, 200), weekly: limit(50, 1000))
        let current = snap.current(at: Date(timeIntervalSince1970: 300))
        #expect(current.session == limit(0, nil))
        #expect(current.weekly.percent == 50)
    }
}

struct FormatTests {
    @Test func countdownFormatting() {
        let now = Date(timeIntervalSince1970: 0)
        #expect(UsageFormat.countdown(to: now.addingTimeInterval(30), from: now) == "now")
        #expect(UsageFormat.countdown(to: now.addingTimeInterval(12 * 60), from: now) == "12m")
        #expect(UsageFormat.countdown(to: now.addingTimeInterval(5795), from: now) == "1h 36m")
        #expect(UsageFormat.countdown(to: now.addingTimeInterval(89195), from: now) == "1d 0h")
        #expect(UsageFormat.age(of: now, from: now.addingTimeInterval(240)) == "4m ago")
    }
}

struct JSONEditTests {
    private func parse(_ text: String) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any]
    }

    @Test func replacesValueAndKeepsEverythingElse() throws {
        let text = """
        {
          "model": "opus",
          "statusLine": {"type": "command", "command": "bash ~/a.sh", "refreshInterval": 10},
          "hooks": {"x": [1, "}{"]}
        }
        """
        let updated = JSONEdit.setTopLevel("statusLine", to: #"{"command":"new"}"#, in: text)
        #expect(updated.contains(#""model": "opus","#))
        #expect(updated.contains(#""hooks": {"x": [1, "}{"]}"#))
        let root = try #require(parse(updated))
        #expect((root["statusLine"] as? [String: Any])?["command"] as? String == "new")
        #expect(JSONEdit.valueText(forTopLevelKey: "statusLine", in: text)
                == #"{"type": "command", "command": "bash ~/a.sh", "refreshInterval": 10}"#)
    }

    @Test func addsKeyWhenMissing() throws {
        let updated = JSONEdit.setTopLevel("statusLine", to: #"{"command":"new"}"#, in: #"{"model": "opus"}"#)
        #expect(parse(updated)?["model"] as? String == "opus")
        #expect(parse(updated)?["statusLine"] != nil)
        #expect(parse(JSONEdit.setTopLevel("statusLine", to: "1", in: "{}"))?["statusLine"] as? Int == 1)
    }

    @Test func removesKeyAnywhere() throws {
        for text in [#"{"statusLine": 1, "a": 2}"#, #"{"a": 2, "statusLine": 1}"#, #"{"a": 2, "statusLine": 1, "b": 3}"#, #"{"statusLine": 1}"#] {
            let updated = JSONEdit.removeTopLevel("statusLine", in: text)
            let root = try #require(parse(updated), "invalid JSON for \(text): \(updated)")
            #expect(root["statusLine"] == nil)
        }
    }
}

struct ConnectionStatusTests {
    @Test func missingClaudeCodeComesFirst() {
        #expect(ConnectionStatus.resolve(install: .notFound, connected: true, hasUsage: true,
                                         sawRequestsWithoutLimits: false) == .claudeCodeMissing)
    }

    @Test func eachStepInOrder() {
        #expect(ConnectionStatus.resolve(install: .neverOpened, connected: false, hasUsage: false,
                                         sawRequestsWithoutLimits: false) == .notConnected(neverOpened: true))
        #expect(ConnectionStatus.resolve(install: .ready, connected: true, hasUsage: false,
                                         sawRequestsWithoutLimits: false) == .waiting(neverOpened: false))
        #expect(ConnectionStatus.resolve(install: .ready, connected: true, hasUsage: false,
                                         sawRequestsWithoutLimits: true) == .noPlanLimits)
        #expect(ConnectionStatus.resolve(install: .ready, connected: true, hasUsage: true,
                                         sawRequestsWithoutLimits: true) == .ok)
    }

    @Test func detectsApiKeySessions() {
        let apiKey = #"{"cost":{"total_api_duration_ms":1200},"context_window":{"total_input_tokens":900}}"#
        let fresh = #"{"cost":{"total_api_duration_ms":0},"context_window":{"total_input_tokens":0}}"#
        let plan = #"{"cost":{"total_api_duration_ms":1200},"rate_limits":{"five_hour":{"used_percentage":5}}}"#
        #expect(Reading.madeRequestsWithoutLimits(Data(apiKey.utf8)))
        #expect(!Reading.madeRequestsWithoutLimits(Data(fresh.utf8)))
        #expect(!Reading.madeRequestsWithoutLimits(Data(plan.utf8)))
        #expect(!Reading.madeRequestsWithoutLimits(Data("nope".utf8)))
    }

    @Test func looksInTheUsualInstallPlaces() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".nvm/versions/node/v22.1.0/bin"),
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = ClaudeCodeInstall.programPaths(home: home, fileManager: .default)
        #expect(paths.contains(home.appendingPathComponent(".local/bin/claude").path))
        #expect(paths.contains("/opt/homebrew/bin/claude"))
        #expect(paths.contains(home.appendingPathComponent(".nvm/versions/node/v22.1.0/bin/claude").path))
    }
}
