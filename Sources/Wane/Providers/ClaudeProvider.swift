import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct ClaudeCredentials: Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let scopes: [String]
    let subscriptionType: String?

    var isExpired: Bool {
        Date() >= expiresAt
    }

    var hasProfileScope: Bool {
        scopes.contains("user:profile")
    }

    static let credentialsPath = NSString("~/.claude/.credentials.json").expandingTildeInPath

    static func parse(from data: Data) throws -> ClaudeCredentials {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = root["claudeAiOauth"] as? [String: Any],
            let accessToken = oauth["accessToken"] as? String,
            let refreshToken = oauth["refreshToken"] as? String,
            let expiresAtMs = oauth["expiresAt"] as? Double
        else {
            throw ProviderError.parseError("Invalid Claude credentials format")
        }

        return ClaudeCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date(timeIntervalSince1970: expiresAtMs / 1_000),
            scopes: oauth["scopes"] as? [String] ?? [],
            subscriptionType: oauth["subscriptionType"] as? String
        )
    }
}

struct ClaudeUsageWindow: Equatable {
    let utilization: Double
    let resetsAt: Date
}

struct ClaudeExtraUsage: Equatable {
    let isEnabled: Bool
    let monthlyLimit: Int?
    let usedCredits: Double
}

struct ClaudeUsageResponse: Equatable {
    let fiveHour: ClaudeUsageWindow?
    let sevenDay: ClaudeUsageWindow?
    let extraUsage: ClaudeExtraUsage?

    var remainingPercentage: Double {
        guard let fiveHour else { return 100.0 }
        return max(0, 100 - fiveHour.utilization)
    }

    static func parse(from data: Data) throws -> ClaudeUsageResponse {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.parseError("Invalid Claude usage response")
        }

        let fiveHour = parseWindow(root["five_hour"])
        let sevenDay = parseWindow(root["seven_day"])
        let extraUsage = parseExtra(root["extra_usage"])

        return ClaudeUsageResponse(fiveHour: fiveHour, sevenDay: sevenDay, extraUsage: extraUsage)
    }

    private static func parseWindow(_ value: Any?) -> ClaudeUsageWindow? {
        guard
            let window = value as? [String: Any],
            let utilization = window["utilization"] as? Double,
            let resetRaw = window["resets_at"] as? String
        else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        guard let resetsAt = formatter.date(from: resetRaw) ?? fallbackFormatter.date(from: resetRaw) else {
            return nil
        }

        return ClaudeUsageWindow(utilization: utilization, resetsAt: resetsAt)
    }

    private static func parseExtra(_ value: Any?) -> ClaudeExtraUsage? {
        guard let extra = value as? [String: Any], let isEnabled = extra["is_enabled"] as? Bool else {
            return nil
        }

        return ClaudeExtraUsage(
            isEnabled: isEnabled,
            monthlyLimit: extra["monthly_limit"] as? Int,
            usedCredits: extra["used_credits"] as? Double ?? 0
        )
    }
}

final class ClaudeProvider: Provider {
    let config = ProviderConfig.claude

    func detect() async -> Bool {
        FileManager.default.fileExists(atPath: ClaudeCredentials.credentialsPath)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard FileManager.default.fileExists(atPath: ClaudeCredentials.credentialsPath) else {
            throw ProviderError.credentialsNotFound
        }

        let credentialData = try Data(contentsOf: URL(fileURLWithPath: ClaudeCredentials.credentialsPath))
        let credentials = try ClaudeCredentials.parse(from: credentialData)

        guard !credentials.isExpired else {
            throw ProviderError.credentialsExpired
        }

        guard credentials.hasProfileScope else {
            throw ProviderError.fetchFailed("Claude token missing user:profile scope")
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.fetchFailed("Claude API returned non-200")
        }

        let usage = try ClaudeUsageResponse.parse(from: responseData)
        return UsageSnapshot(
            remainingPercentage: usage.remainingPercentage,
            resetsAt: usage.fiveHour?.resetsAt,
            dailyUsage: scanLocalUsage()
        )
    }

    /// Scan ~/.claude/projects for JSONL assistant usage entries.
    func scanLocalUsage() -> [DailyUsage] {
        let basePath = NSString("~/.claude/projects").expandingTildeInPath
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
        let timestampFormatter = ISO8601DateFormatter()

        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "jsonl" else { continue }
            if let modifiedAt = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               modifiedAt < thirtyDaysAgo {
                continue
            }

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            for line in content.split(separator: "\n") {
                guard
                    let lineData = line.data(using: .utf8),
                    let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                    obj["type"] as? String == "assistant",
                    let message = obj["message"] as? [String: Any],
                    let usage = message["usage"] as? [String: Any]
                else {
                    continue
                }

                let inputTokens = usage["input_tokens"] as? Int ?? 0
                let outputTokens = usage["output_tokens"] as? Int ?? 0
                let totalTokens = inputTokens + outputTokens

                guard
                    let timestamp = obj["timestamp"] as? String,
                    let date = timestampFormatter.date(from: timestamp)
                else {
                    continue
                }

                let key = keyFormatter.string(from: date)
                dailyCounts[key, default: 0] += totalTokens
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
