import XCTest
@testable import CodeIslandCore

final class DerivedSessionStateTests: XCTestCase {
    func testAllIdleSessionsUseMostRecentlyActiveSource() {
        var older = SessionSnapshot()
        older.source = "claude"
        older.status = .idle
        older.lastActivity = Date(timeIntervalSince1970: 100)

        var newer = SessionSnapshot()
        newer.source = "codex"
        newer.status = .idle
        newer.lastActivity = Date(timeIntervalSince1970: 200)

        let summary = deriveSessionSummary(from: [
            "older": older,
            "newer": newer,
        ])

        XCTAssertEqual(summary.primarySource, "codex")
        XCTAssertEqual(summary.activeSessionCount, 0)
        XCTAssertEqual(summary.totalSessionCount, 2)
    }
}
