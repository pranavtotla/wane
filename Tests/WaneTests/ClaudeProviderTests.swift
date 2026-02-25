import XCTest
@testable import Wane

final class ClaudeProviderTests: XCTestCase {
    func testParseCredentials() throws {
        let json = """
        {
            "claudeAiOauth": {
                "accessToken": "sk-ant-oat01-test-token",
                "refreshToken": "sk-ant-ort01-test-refresh",
                "expiresAt": 9999999999999,
                "scopes": ["user:inference", "user:profile"],
                "subscriptionType": "max",
                "rateLimitTier": "default_claude_max_20x"
            }
        }
        """.data(using: .utf8)!

        let creds = try ClaudeCredentials.parse(from: json)
        XCTAssertEqual(creds.accessToken, "sk-ant-oat01-test-token")
        XCTAssertEqual(creds.refreshToken, "sk-ant-ort01-test-refresh")
        XCTAssertTrue(creds.hasProfileScope)
        XCTAssertFalse(creds.isExpired)
    }

    func testParseExpiredCredentials() throws {
        let json = """
        {
            "claudeAiOauth": {
                "accessToken": "sk-ant-oat01-test-token",
                "refreshToken": "sk-ant-ort01-test-refresh",
                "expiresAt": 1000000000000,
                "scopes": ["user:inference"],
                "subscriptionType": "pro"
            }
        }
        """.data(using: .utf8)!

        let creds = try ClaudeCredentials.parse(from: json)
        XCTAssertTrue(creds.isExpired)
        XCTAssertFalse(creds.hasProfileScope)
    }

    func testParseUsageResponse() throws {
        let json = """
        {
            "five_hour": {
                "utilization": 33.0,
                "resets_at": "2026-02-25T21:00:00.889443+00:00"
            },
            "seven_day": null,
            "extra_usage": {
                "is_enabled": true,
                "monthly_limit": 5000,
                "used_credits": 120.0,
                "utilization": null
            }
        }
        """.data(using: .utf8)!

        let usage = try ClaudeUsageResponse.parse(from: json)
        XCTAssertEqual(usage.fiveHour?.utilization, 33.0)
        XCTAssertNotNil(usage.fiveHour?.resetsAt)
        XCTAssertEqual(usage.extraUsage?.usedCredits, 120.0)
    }

    func testRemainingPercentageCalculation() {
        let usage = ClaudeUsageResponse(
            fiveHour: .init(utilization: 33.0, resetsAt: Date()),
            sevenDay: nil,
            extraUsage: nil
        )
        XCTAssertEqual(usage.remainingPercentage, 67.0)
    }
}
