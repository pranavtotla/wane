import Foundation

enum ProviderError: Error, Equatable {
    case notInstalled
    case credentialsNotFound
    case credentialsExpired
    case fetchFailed(String)
    case parseError(String)
}

enum ProviderStatus: Equatable {
    case ok
    case stale
    case needsReauth
    case notInstalled
}

protocol Provider {
    var config: ProviderConfig { get }
    func detect() async -> Bool
    func fetchUsage() async throws -> UsageSnapshot
}
