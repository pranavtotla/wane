import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct CodexAuth: Equatable {
    let accessToken: String
    let accountId: String
    let refreshToken: String

    static let authPath = NSString("~/.codex/auth.json").expandingTildeInPath

    static func parse(from data: Data) throws -> CodexAuth {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokens = root["tokens"] as? [String: Any],
            let accessToken = tokens["access_token"] as? String,
            let accountId = tokens["account_id"] as? String,
            let refreshToken = tokens["refresh_token"] as? String
        else {
            throw ProviderError.parseError("Invalid Codex auth format")
        }

        return CodexAuth(
            accessToken: accessToken,
            accountId: accountId,
            refreshToken: refreshToken
        )
    }
}

struct CodexUsageResponse: Equatable {
    let primaryUsedPercent: Double
    let primaryResetsAt: Date?
    let secondaryUsedPercent: Double
    let secondaryResetsAt: Date?
    let creditsBalance: Double?
    let planType: String?

    var remainingPercentage: Double {
        max(0, 100.0 - primaryUsedPercent)
    }

    static func parse(from data: Data) throws -> CodexUsageResponse {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rateLimit = root["rate_limit"] as? [String: Any]
        else {
            throw ProviderError.parseError("Invalid Codex usage response")
        }

        let primary = rateLimit["primary_window"] as? [String: Any]
        let secondary = rateLimit["secondary_window"] as? [String: Any]
        let credits = root["credits"] as? [String: Any]

        return CodexUsageResponse(
            primaryUsedPercent: jsonNumber(from: primary?["used_percent"]) ?? 0,
            primaryResetsAt: jsonNumber(from: primary?["reset_at"]).map { Date(timeIntervalSince1970: $0) },
            secondaryUsedPercent: jsonNumber(from: secondary?["used_percent"]) ?? 0,
            secondaryResetsAt: jsonNumber(from: secondary?["reset_at"]).map { Date(timeIntervalSince1970: $0) },
            creditsBalance: jsonNumber(from: credits?["balance"]),
            planType: root["plan_type"] as? String
        )
    }

}

final class CodexProvider: Provider {
    let config = ProviderConfig.codex

    func detect() async -> Bool {
        FileManager.default.fileExists(atPath: CodexAuth.authPath)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard FileManager.default.fileExists(atPath: CodexAuth.authPath) else {
            throw ProviderError.credentialsNotFound
        }

        let authData = try Data(contentsOf: URL(fileURLWithPath: CodexAuth.authPath))
        let auth = try CodexAuth.parse(from: authData)

        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.fetchFailed("Codex API returned non-200")
        }

        let usage = try CodexUsageResponse.parse(from: responseData)
        return UsageSnapshot(
            remainingPercentage: usage.remainingPercentage,
            resetsAt: usage.primaryResetsAt,
            dailyUsage: scanLocalSessions(),
            planName: usage.planType?.capitalized,
            extraUsageSpent: nil,
            extraUsageLimit: nil
        )
    }

    /// Scan ~/.codex/sessions for token_count events.
    func scanLocalSessions() -> [DailyUsage] {
        let basePath = NSString("~/.codex/sessions").expandingTildeInPath
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: basePath),
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
        var dailyCounts: [String: Int] = [:]
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "jsonl" else { continue }
            if let modifiedAt = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               modifiedAt < thirtyDaysAgo {
                continue
            }

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            // Find the last token_count event with total_token_usage per session file
            var sessionTotal = 0
            var sessionDate: String?

            for line in content.split(separator: "\n") {
                guard
                    let lineData = line.data(using: .utf8),
                    let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                    obj["type"] as? String == "event_msg",
                    let payload = obj["payload"] as? [String: Any],
                    payload["type"] as? String == "token_count",
                    let info = payload["info"] as? [String: Any],
                    let totalUsage = info["total_token_usage"] as? [String: Any],
                    let totalTokens = totalUsage["total_tokens"] as? Int
                else {
                    continue
                }

                sessionTotal = totalTokens

                if sessionDate == nil,
                   let timestamp = obj["timestamp"] as? String,
                   let date = ISO8601Parsing.date(from: timestamp) {
                    sessionDate = keyFormatter.string(from: date)
                }
            }

            if let key = sessionDate, sessionTotal > 0 {
                dailyCounts[key, default: 0] += sessionTotal
            }
        }

        return dailyCounts.compactMap { key, count in
            guard let date = keyFormatter.date(from: key), date >= thirtyDaysAgo else {
                return nil
            }
            return DailyUsage(date: date, tokenCount: count)
        }
        .sorted(by: { $0.date < $1.date })
    }
}
