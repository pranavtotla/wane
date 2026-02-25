import Foundation
#if canImport(Combine)
import Combine
#endif

#if canImport(Combine)
@MainActor
final class ProviderManager: ObservableObject {
    @Published var selectedProviderId: String?
    @Published var snapshots: [String: UsageSnapshot] = [:]
    @Published var statuses: [String: ProviderStatus] = [:]
    @Published var lastRefresh: Date?

    private var providers: [String: any Provider] = [:]
    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 120

    var selectedSnapshot: UsageSnapshot? {
        guard let selectedProviderId else { return nil }
        return snapshots[selectedProviderId]
    }

    var selectedConfig: ProviderConfig? {
        guard let selectedProviderId else { return nil }
        return ProviderConfig.all.first(where: { $0.id == selectedProviderId })
    }

    func registerProvider(_ provider: any Provider) {
        providers[provider.config.id] = provider
    }

    func selectProvider(_ id: String) {
        selectedProviderId = id
    }

    func snapshot(for id: String) -> UsageSnapshot? {
        snapshots[id]
    }

    func status(for id: String) -> ProviderStatus {
        statuses[id] ?? .notInstalled
    }

    func detectProviders() async {
        for (id, provider) in providers {
            statuses[id] = await provider.detect() ? .ok : .notInstalled
        }

        if selectedProviderId == nil {
            selectedProviderId = providers.keys.sorted().first(where: { statuses[$0] == .ok })
        }
    }

    func refreshAll() async {
        for (id, provider) in providers where statuses[id] == .ok || statuses[id] == .stale {
            do {
                let snapshot = try await provider.fetchUsage()
                snapshots[id] = snapshot
                statuses[id] = .ok
            } catch ProviderError.credentialsExpired {
                statuses[id] = .needsReauth
            } catch {
                if snapshots[id] != nil {
                    statuses[id] = .stale
                }
            }
        }

        lastRefresh = Date()
    }

    func startPolling(interval: TimeInterval? = nil) {
        if let interval {
            refreshInterval = interval
        }

        stopPolling()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll()
            }
        }
    }

    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func setRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        if refreshTimer != nil {
            startPolling()
        }
    }
}
#else
@MainActor
final class ProviderManager {
    var selectedProviderId: String?
    var snapshots: [String: UsageSnapshot] = [:]
    var statuses: [String: ProviderStatus] = [:]
    var lastRefresh: Date?

    private var providers: [String: any Provider] = [:]
    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 120

    var selectedSnapshot: UsageSnapshot? {
        guard let selectedProviderId else { return nil }
        return snapshots[selectedProviderId]
    }

    var selectedConfig: ProviderConfig? {
        guard let selectedProviderId else { return nil }
        return ProviderConfig.all.first(where: { $0.id == selectedProviderId })
    }

    func registerProvider(_ provider: any Provider) {
        providers[provider.config.id] = provider
    }

    func selectProvider(_ id: String) {
        selectedProviderId = id
    }

    func snapshot(for id: String) -> UsageSnapshot? {
        snapshots[id]
    }

    func status(for id: String) -> ProviderStatus {
        statuses[id] ?? .notInstalled
    }

    func detectProviders() async {
        for (id, provider) in providers {
            statuses[id] = await provider.detect() ? .ok : .notInstalled
        }

        if selectedProviderId == nil {
            selectedProviderId = providers.keys.sorted().first(where: { statuses[$0] == .ok })
        }
    }

    func refreshAll() async {
        for (id, provider) in providers where statuses[id] == .ok || statuses[id] == .stale {
            do {
                let snapshot = try await provider.fetchUsage()
                snapshots[id] = snapshot
                statuses[id] = .ok
            } catch ProviderError.credentialsExpired {
                statuses[id] = .needsReauth
            } catch {
                if snapshots[id] != nil {
                    statuses[id] = .stale
                }
            }
        }

        lastRefresh = Date()
    }

    func startPolling(interval: TimeInterval? = nil) {
        if let interval {
            refreshInterval = interval
        }

        stopPolling()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll()
            }
        }
    }

    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func setRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        if refreshTimer != nil {
            startPolling()
        }
    }
}
#endif
