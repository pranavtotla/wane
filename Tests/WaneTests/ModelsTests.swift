import XCTest
@testable import Wane

final class ModelsTests: XCTestCase {
    func testMoonPhaseFromPercentageThresholds() {
        XCTAssertEqual(MoonPhase.from(percentage: 90), .full)
        XCTAssertEqual(MoonPhase.from(percentage: 85), .gibbous)
        XCTAssertEqual(MoonPhase.from(percentage: 70), .gibbous)
        XCTAssertEqual(MoonPhase.from(percentage: 50), .quarter)
        XCTAssertEqual(MoonPhase.from(percentage: 20), .crescent)
        XCTAssertEqual(MoonPhase.from(percentage: 5), .new)
        XCTAssertEqual(MoonPhase.from(percentage: 0), .new)
    }

    func testMoonColorThresholds() {
        XCTAssertEqual(MoonPhase.color(forPercentage: 70), .white)
        XCTAssertEqual(MoonPhase.color(forPercentage: 45), .amber)
        XCTAssertEqual(MoonPhase.color(forPercentage: 20), .orange)
        XCTAssertEqual(MoonPhase.color(forPercentage: 5), .red)
    }

    func testUsageSnapshotComputesMoonState() {
        let snapshot = UsageSnapshot(
            remainingPercentage: 67.0,
            resetsAt: Date().addingTimeInterval(3_600),
            dailyUsage: [DailyUsage(date: Date(), tokenCount: 1_247)]
        )

        XCTAssertEqual(snapshot.moonPhase, .gibbous)
        XCTAssertEqual(snapshot.moonColor, .white)
        XCTAssertEqual(snapshot.dailyUsage.count, 1)
        XCTAssertEqual(UsageSnapshot.empty.remainingPercentage, 100)
        XCTAssertTrue(UsageSnapshot.empty.dailyUsage.isEmpty)
    }

    func testProviderConfigCatalog() {
        XCTAssertEqual(ProviderConfig.claude.id, "claude")
        XCTAssertEqual(ProviderConfig.claude.name, "Claude")
        XCTAssertEqual(ProviderConfig.cursor.id, "cursor")
        XCTAssertEqual(ProviderConfig.codex.id, "codex")
        XCTAssertEqual(ProviderConfig.all.map(\.id), ["claude", "cursor", "codex"])
    }
}
