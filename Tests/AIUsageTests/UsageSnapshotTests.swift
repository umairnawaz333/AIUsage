import Foundation
import Testing
@testable import AIUsage

struct UsageSnapshotTests {
    @Test func parsesFullLine() throws {
        let snap = try #require(UsageSnapshot.parse("1793196805 26 1793202600 41 1793286000\n"))
        #expect(snap.savedAt == Date(timeIntervalSince1970: 1793196805))
        #expect(snap.session == .init(percent: 26, resetsAt: Date(timeIntervalSince1970: 1793202600)))
        #expect(snap.weekly == .init(percent: 41, resetsAt: Date(timeIntervalSince1970: 1793286000)))
    }

    @Test func roundsAndClampsPercentages() throws {
        let snap = try #require(UsageSnapshot.parse("1 26.6 0 140 0"))
        #expect(snap.session.percent == 27)
        #expect(snap.weekly.percent == 100)
        #expect(snap.session.resetsAt == nil)
    }

    @Test func handlesMissingWeekly() throws {
        let snap = try #require(UsageSnapshot.parse("1 12"))
        #expect(snap.session.percent == 12)
        #expect(snap.weekly == .init(percent: 0, resetsAt: nil))
    }

    @Test func rejectsGarbage() {
        #expect(UsageSnapshot.parse("") == nil)
        #expect(UsageSnapshot.parse("hello world") == nil)
        #expect(UsageSnapshot.parse("1793196805") == nil)
    }

    @Test func passedResetDropsToZero() throws {
        let snap = try #require(UsageSnapshot.parse("100 80 200 50 1000"))
        let current = snap.current(at: Date(timeIntervalSince1970: 300))
        #expect(current.session == .init(percent: 0, resetsAt: nil))
        #expect(current.weekly.percent == 50)
    }

    @Test func countdownFormatting() {
        let now = Date(timeIntervalSince1970: 0)
        #expect(UsageFormat.countdown(to: now.addingTimeInterval(30), from: now) == "now")
        #expect(UsageFormat.countdown(to: now.addingTimeInterval(12 * 60), from: now) == "12m")
        #expect(UsageFormat.countdown(to: now.addingTimeInterval(5795), from: now) == "1h 36m")
        #expect(UsageFormat.countdown(to: now.addingTimeInterval(89195), from: now) == "1d 0h")
        #expect(UsageFormat.age(of: now, from: now.addingTimeInterval(240)) == "4m ago")
    }
}
