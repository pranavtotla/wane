import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct CursorUsageSummary: Equatable {
    let planUsedPercent: Double
    let billingCycleEnd: Date?
    let isUnlimited: Bool

    var remainingPercentage: Double {
        if isUnlimited { return 100.0 }
        return max(0, 100.0 - planUsedPercent)
    }

    static func parse(from data: Data) throws -> CursorUsageSummary {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.parseError("Invalid Cursor usage response")
        }

        let isUnlimited = root["isUnlimited"] as? Bool ?? false
        let individualUsage = root["individualUsage"] as? [String: Any]
        let plan = individualUsage?["plan"] as? [String: Any]

        // Use used/limit for accurate plan percentage (totalPercentUsed includes bonus credits)
        let used = Self.number(from: plan?["used"]) ?? 0
        let limit = Self.number(from: plan?["limit"]) ?? 0
        let planUsedPercent = limit > 0 ? min(100, (used / limit) * 100) : 0

        let cycleEnd: Date? = {
            guard let raw = root["billingCycleEnd"] as? String else { return nil }
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            return fractional.date(from: raw) ?? standard.date(from: raw)
        }()

        return CursorUsageSummary(
            planUsedPercent: planUsedPercent,
            billingCycleEnd: cycleEnd,
            isUnlimited: isUnlimited
        )
    }

    private static func number(from value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String { return Double(string) }
        return nil
    }
}

final class CursorProvider: Provider {
    let config = ProviderConfig.cursor

    static let stateDbPath = NSString(
        "~/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    ).expandingTildeInPath

    func detect() async -> Bool {
        FileManager.default.fileExists(atPath: Self.stateDbPath)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard let cookieHeader = CursorSession.load() else {
            throw ProviderError.credentialsExpired
        }

        var request = URLRequest(url: URL(string: "https://cursor.com/api/usage-summary")!)
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.fetchFailed("Cursor: no HTTP response")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            CursorSession.clear()
            throw ProviderError.credentialsExpired
        }

        guard httpResponse.statusCode == 200 else {
            throw ProviderError.fetchFailed("Cursor API returned \(httpResponse.statusCode)")
        }

        let summary = try CursorUsageSummary.parse(from: data)
        let membershipType = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["membershipType"] as? String
        return UsageSnapshot(
            remainingPercentage: summary.remainingPercentage,
            resetsAt: summary.billingCycleEnd,
            dailyUsage: [],
            planName: membershipType?.capitalized,
            extraUsageSpent: nil,
            extraUsageLimit: nil
        )
    }
}
