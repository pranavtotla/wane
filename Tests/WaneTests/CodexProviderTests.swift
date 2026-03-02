import XCTest
@testable import Wane

final class CodexProviderTests: XCTestCase {
    func testParseAuthJson() throws {
        let json = """
        {
            "last_refresh": "2026-02-24T09:21:25Z",
            "OPENAI_API_KEY": null,
            "tokens": {
                "access_token": "eyJ-test-token",
                "account_id": "bda17ade-test-account",
                "refresh_token": "rt_test_refresh"
            }
        }
        """.data(using: .utf8)!

        let auth = try CodexAuth.parse(from: json)
        XCTAssertEqual(auth.accessToken, "eyJ-test-token")
        XCTAssertEqual(auth.accountId, "bda17ade-test-account")
        XCTAssertEqual(auth.refreshToken, "rt_test_refresh")
    }

    func testParseUsageResponse() throws {
        let json = """
        {
            "plan_type": "plus",
            "rate_limit": {
                "primary_window": {
                    "used_percent": 25,
                    "reset_at": 1772089662,
                    "limit_window_seconds": 18000
                },
                "secondary_window": {
                    "used_percent": 10,
                    "reset_at": 1772676462,
                    "limit_window_seconds": 604800
                }
            },
            "credits": {
                "has_credits": false,
                "unlimited": false,
                "balance": 0
            }
        }
        """.data(using: .utf8)!

        let usage = try CodexUsageResponse.parse(from: json)
        XCTAssertEqual(usage.primaryUsedPercent, 25)
        XCTAssertEqual(usage.secondaryUsedPercent, 10)
        XCTAssertEqual(usage.remainingPercentage, 75.0)
        XCTAssertEqual(usage.planType, "plus")
    }
}
