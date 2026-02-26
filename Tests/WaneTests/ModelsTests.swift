import XCTest
@testable import Wane

final class ModelsTests: XCTestCase {
    func testProviderConfigCatalog() {
        XCTAssertEqual(ProviderConfig.all.count, 3)
        XCTAssertEqual(ProviderConfig.claude.name, "Claude")
        XCTAssertEqual(ProviderConfig.cursor.name, "Cursor")
        XCTAssertEqual(ProviderConfig.codex.name, "Codex")
        // Order: codex, claude, cursor (matching CodexBar's tab order)
        XCTAssertEqual(ProviderConfig.all.map(\.id), ["codex", "claude", "cursor"])
    }

    func testUsageSnapshotEmpty() {
        let empty = UsageSnapshot.empty
        XCTAssertEqual(empty.remainingPercentage, 100)
        XCTAssertNil(empty.resetsAt)
        XCTAssertTrue(empty.dailyUsage.isEmpty)
        XCTAssertNil(empty.planName)
    }

    func testUsageSnapshotTodayTokens() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let snapshot = UsageSnapshot(
            remainingPercentage: 50,
            resetsAt: nil,
            dailyUsage: [
                DailyUsage(date: today, tokenCount: 1000),
                DailyUsage(date: yesterday, tokenCount: 2000),
            ],
            planName: "Max",
            extraUsageSpent: nil,
            extraUsageLimit: nil
        )

        XCTAssertEqual(snapshot.todayTokens, 1000)
        XCTAssertEqual(snapshot.last7DaysTokens, 3000)
        XCTAssertEqual(snapshot.last30DaysTokens, 3000)
    }

    func testUsageSnapshotLast7DaysExcludesOldData() {
        let calendar = Calendar.current
        let today = Date()
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: today)!
        let snapshot = UsageSnapshot(
            remainingPercentage: 50,
            resetsAt: nil,
            dailyUsage: [
                DailyUsage(date: today, tokenCount: 500),
                DailyUsage(date: threeDaysAgo, tokenCount: 1500),
                DailyUsage(date: tenDaysAgo, tokenCount: 3000),
            ],
            planName: nil,
            extraUsageSpent: nil,
            extraUsageLimit: nil
        )

        XCTAssertEqual(snapshot.todayTokens, 500)
        XCTAssertEqual(snapshot.last7DaysTokens, 2000)
        XCTAssertEqual(snapshot.last30DaysTokens, 5000)
    }

    func testUsageSnapshotWithExtraUsage() {
        let snapshot = UsageSnapshot(
            remainingPercentage: 67,
            resetsAt: Date(),
            dailyUsage: [],
            planName: "Pro",
            extraUsageSpent: 12.50,
            extraUsageLimit: 50.0
        )

        XCTAssertEqual(snapshot.extraUsageSpent, 12.50)
        XCTAssertEqual(snapshot.extraUsageLimit, 50.0)
        XCTAssertEqual(snapshot.planName, "Pro")
    }
}
