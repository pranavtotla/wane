import XCTest
@testable import Wane

final class CursorProviderTests: XCTestCase {
    func testParseUsageSummary() throws {
        let json = """
        {
            "billingCycleStart": "2026-02-01T00:00:00.000Z",
            "billingCycleEnd": "2026-03-01T00:00:00.000Z",
            "membershipType": "pro",
            "individualUsage": {
                "plan": {
                    "enabled": true,
                    "used": 1500,
                    "limit": 5000,
                    "remaining": 3500,
                    "totalPercentUsed": 30.0
                },
                "onDemand": {
                    "enabled": true,
                    "used": 500,
                    "limit": 10000,
                    "remaining": 9500
                }
            }
        }
        """.data(using: .utf8)!

        let summary = try CursorUsageSummary.parse(from: json)
        XCTAssertEqual(summary.planUsedPercent, 30.0)
        XCTAssertEqual(summary.remainingPercentage, 70.0)
        XCTAssertNotNil(summary.billingCycleEnd)
        XCTAssertEqual(summary.membershipType, "pro")
    }

    func testParseUnlimitedPlan() throws {
        let json = """
        {
            "billingCycleStart": "2026-02-01T00:00:00.000Z",
            "billingCycleEnd": "2026-03-01T00:00:00.000Z",
            "membershipType": "enterprise",
            "isUnlimited": true,
            "individualUsage": {
                "plan": {
                    "enabled": true,
                    "used": 0,
                    "limit": 0,
                    "remaining": 0,
                    "totalPercentUsed": 0
                }
            }
        }
        """.data(using: .utf8)!

        let summary = try CursorUsageSummary.parse(from: json)
        XCTAssertTrue(summary.isUnlimited)
        XCTAssertEqual(summary.remainingPercentage, 100.0)
    }
}
