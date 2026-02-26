import XCTest
@testable import Wane

@MainActor
final class ProviderManagerTests: XCTestCase {
    final class MockProvider: Provider {
        let config: ProviderConfig
        let detected: Bool
        let fetchClosure: () async throws -> UsageSnapshot

        init(
            config: ProviderConfig,
            detected: Bool = true,
            fetchClosure: @escaping () async throws -> UsageSnapshot = { .empty }
        ) {
            self.config = config
            self.detected = detected
            self.fetchClosure = fetchClosure
        }

        func detect() async -> Bool {
            detected
        }

        func fetchUsage() async throws -> UsageSnapshot {
            try await fetchClosure()
        }
    }

    func testInitialState() {
        let manager = ProviderManager()
        XCTAssertNil(manager.selectedProviderId)
        XCTAssertTrue(manager.snapshots.isEmpty)
    }

    func testSelectProvider() {
        let manager = ProviderManager()
        manager.selectProvider("claude")
        XCTAssertEqual(manager.selectedProviderId, "claude")
    }

    func testSnapshotForProvider() {
        let manager = ProviderManager()
        let snapshot = UsageSnapshot(
            remainingPercentage: 67.0,
            resetsAt: Date(),
            dailyUsage: [],
            planName: nil,
            extraUsageSpent: nil,
            extraUsageLimit: nil
        )
        manager.snapshots["claude"] = snapshot
        XCTAssertEqual(manager.snapshot(for: "claude")?.remainingPercentage, 67.0)
    }

    func testStatusForUnknownProvider() {
        let manager = ProviderManager()
        XCTAssertEqual(manager.status(for: "unknown"), .notInstalled)
    }

    func testDetectProvidersAutoSelectsFirstDetected() async {
        let manager = ProviderManager()
        manager.registerProvider(MockProvider(config: .claude, detected: false))
        manager.registerProvider(MockProvider(config: .codex, detected: true))

        await manager.detectProviders()

        XCTAssertEqual(manager.status(for: "claude"), .notInstalled)
        XCTAssertEqual(manager.status(for: "codex"), .ok)
        XCTAssertEqual(manager.selectedProviderId, "codex")
    }

    func testRefreshAllUpdatesSnapshotAndStatus() async {
        let manager = ProviderManager()
        manager.registerProvider(
            MockProvider(config: .claude, detected: true) {
                UsageSnapshot(remainingPercentage: 67, resetsAt: Date(), dailyUsage: [], planName: nil, extraUsageSpent: nil, extraUsageLimit: nil)
            }
        )

        await manager.detectProviders()
        await manager.refreshAll()

        XCTAssertEqual(manager.status(for: "claude"), .ok)
        XCTAssertEqual(manager.snapshot(for: "claude")?.remainingPercentage, 67)
        XCTAssertNotNil(manager.lastRefresh)
    }

    func testRefreshAllMarksNeedsReauthOnExpiredCredentials() async {
        let manager = ProviderManager()
        manager.registerProvider(
            MockProvider(config: .claude, detected: true) {
                throw ProviderError.credentialsExpired
            }
        )

        await manager.detectProviders()
        await manager.refreshAll()

        XCTAssertEqual(manager.status(for: "claude"), .needsReauth)
    }
}
