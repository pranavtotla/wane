import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(SQLite3)
import SQLite3
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
        let planUsedPercent = Self.number(from: plan?["totalPercentUsed"]) ?? 0

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
        let accessToken = try readAccessToken()

        var request = URLRequest(url: URL(string: "https://cursor.com/api/usage-summary")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            let summary = try CursorUsageSummary.parse(from: data)
            return UsageSnapshot(
                remainingPercentage: summary.remainingPercentage,
                resetsAt: summary.billingCycleEnd,
                dailyUsage: []
            )
        }

        return try await fetchUsageWithCookie(accessToken: accessToken)
    }

    private func fetchUsageWithCookie(accessToken: String) async throws -> UsageSnapshot {
        var request = URLRequest(url: URL(string: "https://cursor.com/api/usage-summary")!)
        request.setValue("WorkosCursorSessionToken=\(accessToken)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.fetchFailed("Cursor API returned non-200")
        }

        let summary = try CursorUsageSummary.parse(from: data)
        return UsageSnapshot(
            remainingPercentage: summary.remainingPercentage,
            resetsAt: summary.billingCycleEnd,
            dailyUsage: []
        )
    }

    func readAccessToken() throws -> String {
        #if canImport(SQLite3)
        var database: OpaquePointer?
        guard sqlite3_open_v2(Self.stateDbPath, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw ProviderError.credentialsNotFound
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let query = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken'"
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw ProviderError.credentialsNotFound
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW, let value = sqlite3_column_text(statement, 0) else {
            throw ProviderError.credentialsNotFound
        }

        return String(cString: value)
        #else
        throw ProviderError.credentialsNotFound
        #endif
    }
}
