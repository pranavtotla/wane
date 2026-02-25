import XCTest
@testable import Wane

final class StarFieldTests: XCTestCase {
    func testBrightnessLevel() {
        let levels = StarFieldViewModel.brightnessLevels(
            for: [0, 50, 100, 200, 300],
            average: 100
        )
        XCTAssertEqual(levels[0], 0)
        XCTAssertEqual(levels[1], 1)
        XCTAssertEqual(levels[2], 2)
        XCTAssertEqual(levels[3], 3)
        XCTAssertEqual(levels[4], 4)
    }

    func testEmptyUsageAllZero() {
        let levels = StarFieldViewModel.brightnessLevels(for: [], average: 0)
        XCTAssertTrue(levels.isEmpty)
    }

    func testPadTo30Days() {
        let usage = [
            DailyUsage(date: Date(), tokenCount: 500)
        ]
        let padded = StarFieldViewModel.padTo30Days(usage)
        XCTAssertEqual(padded.count, 30)
        XCTAssertEqual(padded.last?.tokenCount, 500)
    }
}
