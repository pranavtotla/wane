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
}
