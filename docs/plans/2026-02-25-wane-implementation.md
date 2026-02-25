# Wane Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS menu bar app that shows AI coding tool usage as a waning moon icon with a star field heat map popover.

**Architecture:** Swift + SwiftUI menu bar app with no dock icon. Each provider (Claude, Cursor, Codex) has a fetcher that reads local credential files and calls usage APIs — no browser cookie scraping. A `ProviderManager` orchestrates polling, caching, and state. The UI is a popover attached to an `NSStatusItem` with a custom Core Graphics moon icon.

**Tech Stack:** Swift 5.9+, SwiftUI, Core Graphics, SPM, macOS 14+ (Sonoma), SQLite3 (for Cursor's state.vscdb)

---

## Task 1: Project Scaffold & Empty App Shell

**Files:**
- Create: `Package.swift`
- Create: `Sources/Wane/App/WaneApp.swift`
- Create: `Sources/Wane/App/AppDelegate.swift`

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Wane",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Wane", targets: ["Wane"])
    ],
    targets: [
        .executableTarget(
            name: "Wane",
            path: "Sources/Wane",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Sources/Wane/Resources/Info.plist"])
            ]
        ),
        .testTarget(
            name: "WaneTests",
            dependencies: ["Wane"],
            path: "Tests/WaneTests"
        )
    ]
)
```

**Step 2: Create Info.plist**

Create `Sources/Wane/Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleName</key>
    <string>Wane</string>
    <key>CFBundleIdentifier</key>
    <string>com.wane.app</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
</dict>
</plist>
```

`LSUIElement = true` hides the dock icon.

**Step 3: Create AppDelegate.swift**

```swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "Wane")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: Text("Wane"))
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
```

**Step 4: Create WaneApp.swift**

```swift
import AppKit

@main
struct WaneApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
```

**Step 5: Build and run**

Run: `swift build`
Expected: Compiles. A moon icon appears in the status bar. Clicking shows a popover with "Wane" text.

**Step 6: Commit**

```bash
git add Package.swift Sources/ Tests/
git commit -m "feat: scaffold Wane app with status bar icon and empty popover"
```

---

## Task 2: Data Models

**Files:**
- Create: `Sources/Wane/Models/UsageData.swift`
- Create: `Sources/Wane/Models/ProviderConfig.swift`
- Create: `Tests/WaneTests/ModelsTests.swift`

**Step 1: Write the failing tests**

```swift
import XCTest
@testable import Wane

final class ModelsTests: XCTestCase {
    func testMoonPhaseFromPercentage() {
        XCTAssertEqual(MoonPhase.from(percentage: 90), .full)
        XCTAssertEqual(MoonPhase.from(percentage: 85), .gibbous)
        XCTAssertEqual(MoonPhase.from(percentage: 70), .gibbous)
        XCTAssertEqual(MoonPhase.from(percentage: 50), .quarter)
        XCTAssertEqual(MoonPhase.from(percentage: 20), .crescent)
        XCTAssertEqual(MoonPhase.from(percentage: 5), .new)
        XCTAssertEqual(MoonPhase.from(percentage: 0), .new)
    }

    func testMoonPhaseColor() {
        // >60% = soft white
        XCTAssertEqual(MoonPhase.color(forPercentage: 70), MoonPhase.Color.white)
        // 35-60% = amber
        XCTAssertEqual(MoonPhase.color(forPercentage: 45), MoonPhase.Color.amber)
        // 10-35% = orange
        XCTAssertEqual(MoonPhase.color(forPercentage: 20), MoonPhase.Color.orange)
        // <10% = red
        XCTAssertEqual(MoonPhase.color(forPercentage: 5), MoonPhase.Color.red)
    }

    func testProviderConfig() {
        let claude = ProviderConfig.claude
        XCTAssertEqual(claude.name, "Claude")
        XCTAssertEqual(claude.id, "claude")
    }

    func testUsageSnapshot() {
        let snapshot = UsageSnapshot(
            remainingPercentage: 67.0,
            resetsAt: Date().addingTimeInterval(3600),
            dailyUsage: [
                DailyUsage(date: Date(), tokenCount: 1247)
            ]
        )
        XCTAssertEqual(snapshot.moonPhase, .gibbous)
        XCTAssertEqual(snapshot.dailyUsage.count, 1)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter ModelsTests`
Expected: FAIL — types don't exist yet

**Step 3: Implement UsageData.swift**

```swift
import Foundation
import SwiftUI

enum MoonPhase: Equatable {
    case full      // >85%
    case gibbous   // 60-85%
    case quarter   // 35-60%
    case crescent  // 10-35%
    case new       // <10%

    static func from(percentage: Double) -> MoonPhase {
        switch percentage {
        case 85.1...: return .full
        case 60...85: return .gibbous
        case 35..<60: return .quarter
        case 10..<35: return .crescent
        default: return .new
        }
    }

    enum Color: Equatable {
        case white   // >60%
        case amber   // 35-60%
        case orange  // 10-35%
        case red     // <10%
    }

    static func color(forPercentage p: Double) -> Color {
        switch p {
        case 60.1...: return .white
        case 35...60: return .amber
        case 10..<35: return .orange
        default: return .red
        }
    }
}

struct DailyUsage: Equatable {
    let date: Date
    let tokenCount: Int
}

struct UsageSnapshot {
    let remainingPercentage: Double
    let resetsAt: Date?
    let dailyUsage: [DailyUsage]

    var moonPhase: MoonPhase {
        MoonPhase.from(percentage: remainingPercentage)
    }

    var moonColor: MoonPhase.Color {
        MoonPhase.color(forPercentage: remainingPercentage)
    }

    static let empty = UsageSnapshot(remainingPercentage: 100, resetsAt: nil, dailyUsage: [])
}
```

**Step 4: Implement ProviderConfig.swift**

```swift
import SwiftUI

struct ProviderConfig: Identifiable, Equatable {
    let id: String
    let name: String
    let tintColor: SwiftUI.Color

    static let claude = ProviderConfig(id: "claude", name: "Claude", tintColor: Color(hex: 0xD97757))
    static let cursor = ProviderConfig(id: "cursor", name: "Cursor", tintColor: Color(hex: 0x7B61FF))
    static let codex = ProviderConfig(id: "codex", name: "Codex", tintColor: Color(hex: 0x10A37F))

    static let all: [ProviderConfig] = [.claude, .cursor, .codex]
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
```

**Step 5: Run tests to verify they pass**

Run: `swift test --filter ModelsTests`
Expected: PASS

**Step 6: Commit**

```bash
git add Sources/Wane/Models/ Tests/WaneTests/ModelsTests.swift
git commit -m "feat: add data models for moon phases, usage snapshots, and provider config"
```

---

## Task 3: Token Formatter

**Files:**
- Create: `Sources/Wane/Services/TokenFormatter.swift`
- Create: `Tests/WaneTests/TokenFormatterTests.swift`

**Step 1: Write the failing tests**

```swift
import XCTest
@testable import Wane

final class TokenFormatterTests: XCTestCase {
    func testSubThousand() {
        XCTAssertEqual(TokenFormatter.compact(0), "0")
        XCTAssertEqual(TokenFormatter.compact(1), "1")
        XCTAssertEqual(TokenFormatter.compact(847), "847")
        XCTAssertEqual(TokenFormatter.compact(999), "999")
    }

    func testThousands() {
        XCTAssertEqual(TokenFormatter.compact(1000), "1K")
        XCTAssertEqual(TokenFormatter.compact(1200), "1.2K")
        XCTAssertEqual(TokenFormatter.compact(1247), "1.2K")
        XCTAssertEqual(TokenFormatter.compact(8432), "8.4K")
        XCTAssertEqual(TokenFormatter.compact(31506), "31.5K")
        XCTAssertEqual(TokenFormatter.compact(312000), "312K")
        XCTAssertEqual(TokenFormatter.compact(999999), "1M")
    }

    func testMillions() {
        XCTAssertEqual(TokenFormatter.compact(1_000_000), "1M")
        XCTAssertEqual(TokenFormatter.compact(1_200_000), "1.2M")
        XCTAssertEqual(TokenFormatter.compact(84_300_000), "84.3M")
    }

    func testBillions() {
        XCTAssertEqual(TokenFormatter.compact(1_000_000_000), "1B")
        XCTAssertEqual(TokenFormatter.compact(1_200_000_000), "1.2B")
        XCTAssertEqual(TokenFormatter.compact(4_600_000_000), "4.6B")
    }

    func testExactFormat() {
        XCTAssertEqual(TokenFormatter.exact(31506), "31,506")
        XCTAssertEqual(TokenFormatter.exact(1247), "1,247")
        XCTAssertEqual(TokenFormatter.exact(0), "0")
        XCTAssertEqual(TokenFormatter.exact(1_000_000), "1,000,000")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter TokenFormatterTests`
Expected: FAIL

**Step 3: Implement TokenFormatter.swift**

```swift
import Foundation

enum TokenFormatter {
    static func compact(_ count: Int) -> String {
        switch count {
        case ..<1_000:
            return "\(count)"
        case ..<1_000_000:
            let k = Double(count) / 1_000
            return formatUnit(k, suffix: "K")
        case ..<1_000_000_000:
            let m = Double(count) / 1_000_000
            return formatUnit(m, suffix: "M")
        default:
            let b = Double(count) / 1_000_000_000
            return formatUnit(b, suffix: "B")
        }
    }

    static func exact(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private static func formatUnit(_ value: Double, suffix: String) -> String {
        if value >= 999.95 && suffix == "K" {
            return formatUnit(value / 1_000, suffix: "M")
        }
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))\(suffix)"
        }
        return String(format: "%.1f%@", rounded, suffix)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter TokenFormatterTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/Wane/Services/TokenFormatter.swift Tests/WaneTests/TokenFormatterTests.swift
git commit -m "feat: add compact token formatter (1.2K, 8.4M, 4.6B)"
```

---

## Task 4: Provider Protocol & Claude Provider

**Files:**
- Create: `Sources/Wane/Providers/Provider.swift`
- Create: `Sources/Wane/Providers/ClaudeProvider.swift`
- Create: `Tests/WaneTests/ClaudeProviderTests.swift`

**Step 1: Write the failing tests**

```swift
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
        // 33% utilized = 67% remaining
        let usage = ClaudeUsageResponse(
            fiveHour: .init(utilization: 33.0, resetsAt: Date()),
            sevenDay: nil,
            extraUsage: nil
        )
        XCTAssertEqual(usage.remainingPercentage, 67.0)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter ClaudeProviderTests`
Expected: FAIL

**Step 3: Implement Provider.swift**

```swift
import Foundation

enum ProviderError: Error {
    case notInstalled
    case credentialsNotFound
    case credentialsExpired
    case fetchFailed(String)
    case parseError(String)
}

enum ProviderStatus: Equatable {
    case ok
    case stale          // data is old, fetch failed
    case needsReauth    // token expired, can't refresh
    case notInstalled
}

protocol Provider {
    var config: ProviderConfig { get }
    func detect() async -> Bool
    func fetchUsage() async throws -> UsageSnapshot
}
```

**Step 4: Implement ClaudeProvider.swift**

This reads `~/.claude/.credentials.json` and calls `GET https://api.anthropic.com/api/oauth/usage`.

```swift
import Foundation

// MARK: - Credential Parsing

struct ClaudeCredentials {
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

    static func parse(from data: Data) throws -> ClaudeCredentials {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String,
              let refreshToken = oauth["refreshToken"] as? String,
              let expiresAtMs = oauth["expiresAt"] as? Double else {
            throw ProviderError.parseError("Invalid Claude credentials format")
        }
        let scopes = oauth["scopes"] as? [String] ?? []
        let subscriptionType = oauth["subscriptionType"] as? String
        return ClaudeCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date(timeIntervalSince1970: expiresAtMs / 1000),
            scopes: scopes,
            subscriptionType: subscriptionType
        )
    }

    static let credentialsPath = NSString("~/.claude/.credentials.json").expandingTildeInPath
}

// MARK: - Usage API Response

struct ClaudeUsageWindow {
    let utilization: Double
    let resetsAt: Date
}

struct ClaudeExtraUsage {
    let isEnabled: Bool
    let monthlyLimit: Int?
    let usedCredits: Double
}

struct ClaudeUsageResponse {
    let fiveHour: ClaudeUsageWindow?
    let sevenDay: ClaudeUsageWindow?
    let extraUsage: ClaudeExtraUsage?

    var remainingPercentage: Double {
        // Use 5-hour window as the primary indicator
        if let fiveHour = fiveHour {
            return max(0, 100.0 - fiveHour.utilization)
        }
        return 100.0
    }

    static func parse(from data: Data) throws -> ClaudeUsageResponse {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.parseError("Invalid usage response")
        }

        let fiveHour: ClaudeUsageWindow? = {
            guard let window = root["five_hour"] as? [String: Any],
                  let utilization = window["utilization"] as? Double,
                  let resetsAtStr = window["resets_at"] as? String else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let resetsAt = formatter.date(from: resetsAtStr) ?? Date()
            return ClaudeUsageWindow(utilization: utilization, resetsAt: resetsAt)
        }()

        let sevenDay: ClaudeUsageWindow? = {
            guard let window = root["seven_day"] as? [String: Any],
                  let utilization = window["utilization"] as? Double,
                  let resetsAtStr = window["resets_at"] as? String else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let resetsAt = formatter.date(from: resetsAtStr) ?? Date()
            return ClaudeUsageWindow(utilization: utilization, resetsAt: resetsAt)
        }()

        let extraUsage: ClaudeExtraUsage? = {
            guard let extra = root["extra_usage"] as? [String: Any],
                  let isEnabled = extra["is_enabled"] as? Bool else { return nil }
            return ClaudeExtraUsage(
                isEnabled: isEnabled,
                monthlyLimit: extra["monthly_limit"] as? Int,
                usedCredits: extra["used_credits"] as? Double ?? 0
            )
        }()

        return ClaudeUsageResponse(fiveHour: fiveHour, sevenDay: sevenDay, extraUsage: extraUsage)
    }
}

// MARK: - Provider

final class ClaudeProvider: Provider {
    let config = ProviderConfig.claude

    func detect() async -> Bool {
        FileManager.default.fileExists(atPath: ClaudeCredentials.credentialsPath)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        // 1. Read credentials
        let data = try Data(contentsOf: URL(fileURLWithPath: ClaudeCredentials.credentialsPath))
        let creds = try ClaudeCredentials.parse(from: data)

        guard !creds.isExpired else {
            throw ProviderError.credentialsExpired
        }

        guard creds.hasProfileScope else {
            throw ProviderError.fetchFailed("Claude token missing user:profile scope")
        }

        // 2. Call usage API
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.fetchFailed("Claude API returned non-200")
        }

        let usage = try ClaudeUsageResponse.parse(from: responseData)

        // 3. Scan local JSONL for daily token counts
        let dailyUsage = scanLocalUsage()

        return UsageSnapshot(
            remainingPercentage: usage.remainingPercentage,
            resetsAt: usage.fiveHour?.resetsAt,
            dailyUsage: dailyUsage
        )
    }

    /// Scan ~/.claude/projects/ for assistant messages with token usage
    private func scanLocalUsage() -> [DailyUsage] {
        let basePath = NSString("~/.claude/projects").expandingTildeInPath
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: basePath),
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var dailyCounts: [String: Int] = [:] // "YYYY-MM-DD" -> token count
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!

        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "jsonl" else { continue }

            // Skip files older than 30 days by modification date
            if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               modDate < thirtyDaysAgo {
                continue
            }

            guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else { continue }
            defer { fileHandle.closeFile() }

            guard let content = String(data: fileHandle.readDataToEndOfFile(), encoding: .utf8) else { continue }

            for line in content.split(separator: "\n") {
                guard let lineData = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      obj["type"] as? String == "assistant",
                      let message = obj["message"] as? [String: Any],
                      let usage = message["usage"] as? [String: Any] else { continue }

                let input = usage["input_tokens"] as? Int ?? 0
                let output = usage["output_tokens"] as? Int ?? 0
                let total = input + output

                if let timestamp = obj["timestamp"] as? String,
                   let date = ISO8601DateFormatter().date(from: timestamp) {
                    let key = dateFormatter.string(from: date)
                    dailyCounts[key, default: 0] += total
                }
            }
        }

        return dailyCounts.compactMap { key, count in
            guard let date = dateFormatter.date(from: key), date >= thirtyDaysAgo else { return nil }
            return DailyUsage(date: date, tokenCount: count)
        }.sorted { $0.date < $1.date }
    }
}
```

**Step 5: Run tests to verify they pass**

Run: `swift test --filter ClaudeProviderTests`
Expected: PASS

**Step 6: Commit**

```bash
git add Sources/Wane/Providers/ Tests/WaneTests/ClaudeProviderTests.swift
git commit -m "feat: add Provider protocol and Claude provider with OAuth usage API"
```

---

## Task 5: Codex Provider

**Files:**
- Create: `Sources/Wane/Providers/CodexProvider.swift`
- Create: `Tests/WaneTests/CodexProviderTests.swift`

**Step 1: Write the failing tests**

```swift
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
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter CodexProviderTests`
Expected: FAIL

**Step 3: Implement CodexProvider.swift**

```swift
import Foundation

// MARK: - Auth

struct CodexAuth {
    let accessToken: String
    let accountId: String
    let refreshToken: String

    static func parse(from data: Data) throws -> CodexAuth {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              let accountId = tokens["account_id"] as? String,
              let refreshToken = tokens["refresh_token"] as? String else {
            throw ProviderError.parseError("Invalid Codex auth format")
        }
        return CodexAuth(accessToken: accessToken, accountId: accountId, refreshToken: refreshToken)
    }

    static let authPath = NSString("~/.codex/auth.json").expandingTildeInPath
}

// MARK: - Usage Response

struct CodexUsageResponse {
    let primaryUsedPercent: Double
    let primaryResetsAt: Date?
    let secondaryUsedPercent: Double
    let secondaryResetsAt: Date?
    let creditsBalance: Double?

    var remainingPercentage: Double {
        max(0, 100.0 - primaryUsedPercent)
    }

    static func parse(from data: Data) throws -> CodexUsageResponse {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rateLimit = root["rate_limit"] as? [String: Any] else {
            throw ProviderError.parseError("Invalid Codex usage response")
        }

        let primary = rateLimit["primary_window"] as? [String: Any]
        let secondary = rateLimit["secondary_window"] as? [String: Any]
        let credits = root["credits"] as? [String: Any]

        return CodexUsageResponse(
            primaryUsedPercent: primary?["used_percent"] as? Double ?? 0,
            primaryResetsAt: (primary?["reset_at"] as? Double).map { Date(timeIntervalSince1970: $0) },
            secondaryUsedPercent: secondary?["used_percent"] as? Double ?? 0,
            secondaryResetsAt: (secondary?["reset_at"] as? Double).map { Date(timeIntervalSince1970: $0) },
            creditsBalance: credits?["balance"] as? Double
        )
    }
}

// MARK: - Provider

final class CodexProvider: Provider {
    let config = ProviderConfig.codex

    func detect() async -> Bool {
        FileManager.default.fileExists(atPath: CodexAuth.authPath)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        let data = try Data(contentsOf: URL(fileURLWithPath: CodexAuth.authPath))
        let auth = try CodexAuth.parse(from: data)

        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ProviderError.fetchFailed("Codex API returned non-200")
        }

        let usage = try CodexUsageResponse.parse(from: responseData)
        let dailyUsage = scanLocalSessions()

        return UsageSnapshot(
            remainingPercentage: usage.remainingPercentage,
            resetsAt: usage.primaryResetsAt,
            dailyUsage: dailyUsage
        )
    }

    /// Scan ~/.codex/sessions/ for token_count events
    private func scanLocalSessions() -> [DailyUsage] {
        let basePath = NSString("~/.codex/sessions").expandingTildeInPath
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: basePath),
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var dailyCounts: [String: Int] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!

        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "jsonl" else { continue }
            if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               modDate < thirtyDaysAgo { continue }

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            for line in content.split(separator: "\n") {
                guard let lineData = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      obj["type"] as? String == "event_msg",
                      let payload = obj["payload"] as? [String: Any],
                      payload["type"] as? String == "token_count",
                      let info = payload["info"] as? [String: Any],
                      let lastUsage = info["last_token_usage"] as? [String: Any] else { continue }

                let input = lastUsage["input_tokens"] as? Int ?? 0
                let output = lastUsage["output_tokens"] as? Int ?? 0
                let total = input + output

                if let timestamp = obj["timestamp"] as? String,
                   let date = ISO8601DateFormatter().date(from: String(timestamp.prefix(25))) {
                    let key = dateFormatter.string(from: date)
                    dailyCounts[key, default: 0] += total
                }
            }
        }

        return dailyCounts.compactMap { key, count in
            guard let date = dateFormatter.date(from: key), date >= thirtyDaysAgo else { return nil }
            return DailyUsage(date: date, tokenCount: count)
        }.sorted { $0.date < $1.date }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter CodexProviderTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/Wane/Providers/CodexProvider.swift Tests/WaneTests/CodexProviderTests.swift
git commit -m "feat: add Codex provider with ChatGPT usage API and local session scanning"
```

---

## Task 6: Cursor Provider

**Files:**
- Create: `Sources/Wane/Providers/CursorProvider.swift`
- Create: `Tests/WaneTests/CursorProviderTests.swift`

**Step 1: Write the failing tests**

```swift
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
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter CursorProviderTests`
Expected: FAIL

**Step 3: Implement CursorProvider.swift**

Reads the JWT access token from Cursor's local SQLite database. No browser cookies needed.

```swift
import Foundation
import SQLite3

// MARK: - Usage Response

struct CursorUsageSummary {
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
        let individual = root["individualUsage"] as? [String: Any]
        let plan = individual?["plan"] as? [String: Any]
        let usedPercent = plan?["totalPercentUsed"] as? Double ?? 0

        let cycleEnd: Date? = {
            guard let str = root["billingCycleEnd"] as? String else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: str)
        }()

        return CursorUsageSummary(
            planUsedPercent: usedPercent,
            billingCycleEnd: cycleEnd,
            isUnlimited: isUnlimited
        )
    }
}

// MARK: - Provider

final class CursorProvider: Provider {
    let config = ProviderConfig.cursor

    private static let stateDbPath = NSString(
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

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // If Bearer token doesn't work, try as cookie
            return try await fetchUsageWithCookie(accessToken: accessToken)
        }

        let summary = try CursorUsageSummary.parse(from: data)

        return UsageSnapshot(
            remainingPercentage: summary.remainingPercentage,
            resetsAt: summary.billingCycleEnd,
            dailyUsage: [] // Cursor doesn't expose daily token counts
        )
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

    /// Read access token from Cursor's local SQLite state database
    private func readAccessToken() throws -> String {
        var db: OpaquePointer?
        guard sqlite3_open_v2(Self.stateDbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw ProviderError.credentialsNotFound
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let query = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken'"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            throw ProviderError.credentialsNotFound
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW,
              let value = sqlite3_column_text(stmt, 0) else {
            throw ProviderError.credentialsNotFound
        }

        return String(cString: value)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter CursorProviderTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/Wane/Providers/CursorProvider.swift Tests/WaneTests/CursorProviderTests.swift
git commit -m "feat: add Cursor provider reading token from local SQLite, no cookie scraping"
```

---

## Task 7: ProviderManager

**Files:**
- Create: `Sources/Wane/Services/ProviderManager.swift`
- Create: `Tests/WaneTests/ProviderManagerTests.swift`

**Step 1: Write the failing tests**

```swift
import XCTest
@testable import Wane

final class ProviderManagerTests: XCTestCase {
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
            dailyUsage: []
        )
        manager.snapshots["claude"] = snapshot
        XCTAssertEqual(manager.snapshot(for: "claude")?.remainingPercentage, 67.0)
    }

    func testStatusForUnknownProvider() {
        let manager = ProviderManager()
        XCTAssertEqual(manager.status(for: "unknown"), .notInstalled)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter ProviderManagerTests`
Expected: FAIL

**Step 3: Implement ProviderManager.swift**

```swift
import Foundation
import Combine

@MainActor
final class ProviderManager: ObservableObject {
    @Published var selectedProviderId: String?
    @Published var snapshots: [String: UsageSnapshot] = [:]
    @Published var statuses: [String: ProviderStatus] = [:]
    @Published var lastRefresh: Date?

    private var providers: [String: any Provider] = [:]
    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 120 // 2 minutes default

    var selectedSnapshot: UsageSnapshot? {
        guard let id = selectedProviderId else { return nil }
        return snapshots[id]
    }

    var selectedConfig: ProviderConfig? {
        guard let id = selectedProviderId else { return nil }
        return ProviderConfig.all.first { $0.id == id }
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

    /// Detect installed providers, auto-select the first one found
    func detectProviders() async {
        for (id, provider) in providers {
            let detected = await provider.detect()
            statuses[id] = detected ? .ok : .notInstalled
        }

        // Auto-select first detected provider
        if selectedProviderId == nil {
            selectedProviderId = providers.keys
                .sorted()
                .first { statuses[$0] == .ok }
        }
    }

    /// Fetch usage for all detected providers
    func refreshAll() async {
        for (id, provider) in providers where statuses[id] == .ok || statuses[id] == .stale {
            do {
                let snapshot = try await provider.fetchUsage()
                snapshots[id] = snapshot
                statuses[id] = .ok
            } catch ProviderError.credentialsExpired {
                statuses[id] = .needsReauth
            } catch {
                // Keep old snapshot if we have one, mark as stale
                if snapshots[id] != nil {
                    statuses[id] = .stale
                }
            }
        }
        lastRefresh = Date()
    }

    func startPolling(interval: TimeInterval? = nil) {
        if let interval { refreshInterval = interval }
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
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter ProviderManagerTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/Wane/Services/ProviderManager.swift Tests/WaneTests/ProviderManagerTests.swift
git commit -m "feat: add ProviderManager for orchestrating fetch, caching, and polling"
```

---

## Task 8: Moon Icon Rendering (Core Graphics)

**Files:**
- Create: `Sources/Wane/UI/MoonRenderer.swift`

**Step 1: Implement MoonRenderer.swift**

This renders the 14x14pt moon icon using Core Graphics. The moon phase is drawn by clipping an illuminated circle with a shadow ellipse.

```swift
import AppKit
import CoreGraphics

enum MoonRenderer {
    /// Render a moon icon for the status bar
    /// - Parameters:
    ///   - percentage: remaining quota 0-100
    ///   - tintColor: provider tint color
    ///   - size: icon size (default 14pt for status bar, 48pt for hero)
    static func render(percentage: Double, tintColor: NSColor, size: CGFloat = 14) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2 - 1

            // 1. Draw the glow behind moon in critical state
            if percentage < 10 {
                let glowColor = NSColor(red: 0.71, green: 0.27, blue: 0.27, alpha: 0.12)
                ctx.setFillColor(glowColor.cgColor)
                ctx.fillEllipse(in: rect.insetBy(dx: -1, dy: -1))
            }

            // 2. Draw the full moon circle (illuminated portion color)
            let moonColor = phaseColor(percentage: percentage, tint: tintColor)
            ctx.setFillColor(moonColor.cgColor)
            ctx.fillEllipse(in: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))

            // 3. Draw the shadow to create the phase
            // Shadow is an ellipse that overlaps from the right side
            // As percentage decreases, shadow grows from right to left
            let shadowFraction = 1.0 - (percentage / 100.0)
            if shadowFraction > 0.01 {
                let shadowColor = NSColor(white: 0.08, alpha: 0.92)
                ctx.setFillColor(shadowColor.cgColor)

                // Shadow ellipse offset: moves from right edge toward left
                // At 50% remaining, shadow covers right half
                // At 0% remaining, shadow covers entire circle
                let shadowCenterX: CGFloat
                let shadowWidth: CGFloat

                if shadowFraction <= 0.5 {
                    // Shadow growing from right, still partial
                    let t = shadowFraction * 2 // 0 to 1
                    shadowCenterX = center.x + radius * (1 - t)
                    shadowWidth = radius * 2 * t
                } else {
                    // Shadow past half, use clip approach
                    shadowCenterX = center.x
                    shadowWidth = radius * 2
                }

                // Clip to moon circle
                ctx.saveGState()
                ctx.addEllipse(in: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2
                ))
                ctx.clip()

                // Draw shadow ellipse
                let shadowRect = CGRect(
                    x: shadowCenterX - shadowWidth / 2,
                    y: center.y - radius,
                    width: shadowWidth,
                    height: radius * 2
                )

                if shadowFraction <= 0.5 {
                    ctx.fillEllipse(in: shadowRect)
                } else {
                    // Fill the whole moon, then cut out the illuminated crescent
                    ctx.fill(rect)

                    // Draw illuminated crescent by clearing
                    let crescentFraction = (1.0 - shadowFraction) * 2 // 1 to 0
                    let crescentWidth = radius * 2 * crescentFraction
                    let crescentRect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: crescentWidth,
                        height: radius * 2
                    )
                    ctx.setBlendMode(.clear)
                    ctx.fillEllipse(in: crescentRect)
                    ctx.setBlendMode(.normal)

                    // Redraw the crescent in moon color
                    ctx.setFillColor(moonColor.cgColor)
                    ctx.fillEllipse(in: crescentRect)
                }

                ctx.restoreGState()
            }

            return true
        }

        image.isTemplate = false
        return image
    }

    private static func phaseColor(percentage: Double, tint: NSColor) -> NSColor {
        let baseColor: NSColor
        switch percentage {
        case 60.1...:
            baseColor = NSColor(red: 0.91, green: 0.89, blue: 0.87, alpha: 1) // #E8E4DF
        case 35...60:
            baseColor = NSColor(red: 0.83, green: 0.63, blue: 0.33, alpha: 1) // #D4A054
        case 10..<35:
            baseColor = NSColor(red: 0.77, green: 0.42, blue: 0.23, alpha: 1) // #C46B3A
        default:
            baseColor = NSColor(red: 0.71, green: 0.27, blue: 0.27, alpha: 1) // #B54444
        }

        // Blend with provider tint at 15% opacity
        return baseColor.blended(withFraction: 0.15, of: tint) ?? baseColor
    }
}
```

**Step 2: Verify visually**

Update AppDelegate to use MoonRenderer instead of system symbol:

```swift
// In applicationDidFinishLaunching:
if let button = statusItem.button {
    button.image = MoonRenderer.render(
        percentage: 67,
        tintColor: NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1) // Claude tint
    )
}
```

Run: `swift build && swift run`
Expected: A moon icon appears in the status bar showing ~67% illuminated.

**Step 3: Commit**

```bash
git add Sources/Wane/UI/MoonRenderer.swift
git commit -m "feat: add Core Graphics moon renderer with phase, color, and provider tint"
```

---

## Task 9: Popover — Hero Moon View

**Files:**
- Create: `Sources/Wane/UI/HeroMoonView.swift`
- Create: `Sources/Wane/UI/PopoverView.swift`

**Step 1: Implement HeroMoonView.swift**

```swift
import SwiftUI

struct HeroMoonView: View {
    let snapshot: UsageSnapshot
    let config: ProviderConfig

    var body: some View {
        VStack(spacing: 6) {
            // 48pt moon
            Image(nsImage: MoonRenderer.render(
                percentage: snapshot.remainingPercentage,
                tintColor: NSColor(config.tintColor),
                size: 48
            ))
            .frame(width: 48, height: 48)

            Text(config.name)
                .font(.system(.headline, design: .default, weight: .bold))
                .foregroundColor(.white)

            Text("\(Int(snapshot.remainingPercentage))% remaining")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundColor(moonColor)

            if let resetsAt = snapshot.resetsAt {
                Text("resets in \(resetsAt.relativeDescription)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private var moonColor: SwiftUI.Color {
        switch MoonPhase.color(forPercentage: snapshot.remainingPercentage) {
        case .white: return Color(hex: 0xE8E4DF)
        case .amber: return Color(hex: 0xD4A054)
        case .orange: return Color(hex: 0xC46B3A)
        case .red: return Color(hex: 0xB54444)
        }
    }
}

extension Date {
    var relativeDescription: String {
        let interval = timeIntervalSinceNow
        guard interval > 0 else { return "now" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
```

**Step 2: Implement PopoverView.swift (skeleton with hero)**

```swift
import SwiftUI

struct PopoverView: View {
    @ObservedObject var manager: ProviderManager

    var body: some View {
        VStack(spacing: 0) {
            // Section 1: Hero Moon
            if let snapshot = manager.selectedSnapshot,
               let config = manager.selectedConfig {
                HeroMoonView(snapshot: snapshot, config: config)
            } else {
                Text("No provider selected")
                    .foregroundColor(.secondary)
                    .padding()
            }

            Divider().opacity(0.3)

            // Sections 2-4 will be added in subsequent tasks

            Spacer()
        }
        .frame(width: 280, height: 400)
        .background(.ultraThinMaterial.opacity(0.9))
        .environment(\.colorScheme, .dark)
    }
}
```

**Step 3: Wire popover into AppDelegate**

Update AppDelegate to use PopoverView with a real ProviderManager.

**Step 4: Build and verify**

Run: `swift build`
Expected: Compiles. Popover shows hero moon with provider name and percentage.

**Step 5: Commit**

```bash
git add Sources/Wane/UI/HeroMoonView.swift Sources/Wane/UI/PopoverView.swift
git commit -m "feat: add hero moon view and popover shell with dark theme"
```

---

## Task 10: Popover — Provider Switcher

**Files:**
- Create: `Sources/Wane/UI/ProviderSwitcher.swift`
- Modify: `Sources/Wane/UI/PopoverView.swift`

**Step 1: Implement ProviderSwitcher.swift**

```swift
import SwiftUI

struct ProviderSwitcher: View {
    @ObservedObject var manager: ProviderManager

    var body: some View {
        VStack(spacing: 2) {
            ForEach(ProviderConfig.all) { config in
                let status = manager.status(for: config.id)
                if status != .notInstalled {
                    ProviderRow(
                        config: config,
                        snapshot: manager.snapshot(for: config.id),
                        status: status,
                        isSelected: manager.selectedProviderId == config.id
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            manager.selectProvider(config.id)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}

struct ProviderRow: View {
    let config: ProviderConfig
    let snapshot: UsageSnapshot?
    let status: ProviderStatus
    let isSelected: Bool

    var body: some View {
        HStack {
            // Selection indicator
            Text(isSelected ? "\u{25B8}" : " ")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 12)

            Text(config.name)
                .font(.system(.body, weight: isSelected ? .semibold : .regular))
                .foregroundColor(status == .needsReauth ? .secondary : .white)

            Spacer()

            if let snapshot {
                // Mini moon
                Image(nsImage: MoonRenderer.render(
                    percentage: snapshot.remainingPercentage,
                    tintColor: NSColor(config.tintColor),
                    size: 12
                ))
                .frame(width: 12, height: 12)

                Text("\(Int(snapshot.remainingPercentage))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            } else if status == .needsReauth {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
        .cornerRadius(6)
    }
}
```

**Step 2: Add to PopoverView**

Insert `ProviderSwitcher(manager: manager)` after the hero section divider in PopoverView.

**Step 3: Build and verify**

Run: `swift build`
Expected: Compiles. Provider list shows below hero moon.

**Step 4: Commit**

```bash
git add Sources/Wane/UI/ProviderSwitcher.swift Sources/Wane/UI/PopoverView.swift
git commit -m "feat: add provider switcher with mini moons and selection highlight"
```

---

## Task 11: Popover — Star Field Heat Map

**Files:**
- Create: `Sources/Wane/UI/StarFieldView.swift`
- Create: `Tests/WaneTests/StarFieldTests.swift`

**Step 1: Write the failing tests**

```swift
import XCTest
@testable import Wane

final class StarFieldTests: XCTestCase {
    func testBrightnessLevel() {
        // With average of 100, a day with 0 tokens should be level 0
        let levels = StarFieldViewModel.brightnessLevels(
            for: [0, 50, 100, 200, 300],
            average: 100
        )
        XCTAssertEqual(levels[0], 0) // 0 tokens
        XCTAssertEqual(levels[1], 1) // 50 = half average
        XCTAssertEqual(levels[2], 2) // 100 = average
        XCTAssertEqual(levels[3], 3) // 200 = 2x average
        XCTAssertEqual(levels[4], 4) // 300 = 3x average (peak)
    }

    func testEmptyUsageAllZero() {
        let levels = StarFieldViewModel.brightnessLevels(for: [], average: 0)
        XCTAssertTrue(levels.isEmpty)
    }

    func testPadTo30Days() {
        let usage = [
            DailyUsage(date: Date(), tokenCount: 500)
        ]
        let padded = StarFieldViewModel.padTo30Days(usage)
        XCTAssertEqual(padded.count, 30)
        XCTAssertEqual(padded.last?.tokenCount, 500)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter StarFieldTests`
Expected: FAIL

**Step 3: Implement StarFieldView.swift**

```swift
import SwiftUI

enum StarFieldViewModel {
    static func brightnessLevels(for counts: [Int], average: Double) -> [Int] {
        guard !counts.isEmpty else { return [] }
        let avg = average > 0 ? average : 1.0
        return counts.map { count in
            let ratio = Double(count) / avg
            switch ratio {
            case ..<0.1: return 0
            case ..<0.6: return 1
            case ..<1.4: return 2
            case ..<2.5: return 3
            default: return 4
            }
        }
    }

    static func padTo30Days(_ usage: [DailyUsage]) -> [DailyUsage] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var lookup: [String: Int] = [:]
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        for u in usage {
            lookup[df.string(from: u.date)] = u.tokenCount
        }

        return (0..<30).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -(29 - daysAgo), to: today)!
            let key = df.string(from: date)
            return DailyUsage(date: date, tokenCount: lookup[key] ?? 0)
        }
    }
}

struct StarFieldView: View {
    let dailyUsage: [DailyUsage]
    let tintColor: SwiftUI.Color

    private let columns = 6
    private let rows = 5

    var body: some View {
        let padded = StarFieldViewModel.padTo30Days(dailyUsage)
        let counts = padded.map(\.tokenCount)
        let average = counts.isEmpty ? 0.0 : Double(counts.reduce(0, +)) / Double(counts.count)
        let levels = StarFieldViewModel.brightnessLevels(for: counts, average: average)

        VStack(spacing: 8) {
            // Star grid
            Grid(horizontalSpacing: 12, verticalSpacing: 8) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if index < padded.count {
                                StarDot(
                                    level: levels[index],
                                    isToday: index == padded.count - 1,
                                    tintColor: tintColor,
                                    date: padded[index].date,
                                    tokenCount: padded[index].tokenCount
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

struct StarDot: View {
    let level: Int
    let isToday: Bool
    let tintColor: SwiftUI.Color
    let date: Date
    let tokenCount: Int

    @State private var isHovering = false
    @State private var pulseOpacity: Double = 0.7

    private var dotSize: CGFloat {
        switch level {
        case 0, 1: return 3
        case 2: return 4
        default: return 5
        }
    }

    private var dotOpacity: Double {
        switch level {
        case 0: return 0.15
        case 1: return 0.35
        case 2: return 0.60
        case 3: return 0.85
        default: return 1.0
        }
    }

    var body: some View {
        ZStack {
            // Bloom for peak days
            if level == 4 {
                Circle()
                    .fill(tintColor.opacity(0.3))
                    .frame(width: dotSize + 4, height: dotSize + 4)
                    .blur(radius: 2)
            }

            if isToday {
                // Today: ring with filled center
                ZStack {
                    Circle()
                        .stroke(tintColor.opacity(dotOpacity), lineWidth: 1)
                        .frame(width: dotSize + 2, height: dotSize + 2)
                    Circle()
                        .fill(tintColor.opacity(pulseOpacity))
                        .frame(width: dotSize - 1, height: dotSize - 1)
                }
                .onAppear {
                    if tokenCount > 0 {
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                            pulseOpacity = 1.0
                        }
                    }
                }
            } else {
                Circle()
                    .fill(tintColor.opacity(dotOpacity))
                    .frame(width: dotSize, height: dotSize)
            }
        }
        .scaleEffect(isHovering ? 1.3 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .frame(width: 12, height: 12) // Hit target
        .onHover { hovering in
            isHovering = hovering
        }
        .popover(isPresented: .init(
            get: { isHovering },
            set: { isHovering = $0 }
        )) {
            StarTooltip(date: date, tokenCount: tokenCount)
        }
    }
}

struct StarTooltip: View {
    let date: Date
    let tokenCount: Int

    var body: some View {
        Text("\(date.formatted(.dateTime.month(.abbreviated).day())) \u{00B7} \(TokenFormatter.exact(tokenCount))")
            .font(.system(.caption2, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter StarFieldTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/Wane/UI/StarFieldView.swift Tests/WaneTests/StarFieldTests.swift
git commit -m "feat: add star field 30-day usage heat map with hover tooltips"
```

---

## Task 12: Popover — Usage Summary Row

**Files:**
- Create: `Sources/Wane/UI/UsageSummaryView.swift`

**Step 1: Implement UsageSummaryView.swift**

```swift
import SwiftUI

struct UsageSummaryView: View {
    let dailyUsage: [DailyUsage]

    var body: some View {
        let padded = StarFieldViewModel.padTo30Days(dailyUsage)
        let today = todayCount(padded)
        let sevenDay = lastNDaysCount(padded, n: 7)
        let thirtyDay = lastNDaysCount(padded, n: 30)

        HStack(spacing: 16) {
            SummaryItem(label: "Today", count: today)
            SummaryItem(label: "7d", count: sevenDay)
            SummaryItem(label: "30d", count: thirtyDay)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func todayCount(_ padded: [DailyUsage]) -> Int {
        padded.last?.tokenCount ?? 0
    }

    private func lastNDaysCount(_ padded: [DailyUsage], n: Int) -> Int {
        padded.suffix(n).reduce(0) { $0 + $1.tokenCount }
    }
}

struct SummaryItem: View {
    let label: String
    let count: Int

    @State private var showExact = false

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(.caption2))
                .foregroundColor(.secondary)

            Text(showExact ? TokenFormatter.exact(count) : TokenFormatter.compact(count))
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundColor(.white)
                .contentTransition(.numericText())
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                showExact = hovering
            }
        }
    }
}
```

**Step 2: Build and verify**

Run: `swift build`
Expected: Compiles.

**Step 3: Commit**

```bash
git add Sources/Wane/UI/UsageSummaryView.swift
git commit -m "feat: add usage summary row with compact numbers and hover-to-expand"
```

---

## Task 13: Popover — Footer & Settings

**Files:**
- Create: `Sources/Wane/UI/FooterView.swift`
- Create: `Sources/Wane/UI/SettingsView.swift`
- Modify: `Sources/Wane/UI/PopoverView.swift`

**Step 1: Implement FooterView.swift**

```swift
import SwiftUI

struct FooterView: View {
    @ObservedObject var manager: ProviderManager
    @Binding var showSettings: Bool

    var body: some View {
        HStack {
            Button(action: {
                Task { await manager.refreshAll() }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                    if let lastRefresh = manager.lastRefresh {
                        Text("~\(lastRefresh.timeAgoShort)")
                            .font(.system(.caption2, design: .monospaced))
                    } else {
                        Text("refresh")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

extension Date {
    var timeAgoShort: String {
        let seconds = Int(-timeIntervalSinceNow)
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}
```

**Step 2: Implement SettingsView.swift**

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: ProviderManager
    @Binding var isPresented: Bool
    @AppStorage("refreshInterval") private var refreshInterval: Double = 120
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Button(action: { isPresented = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                        Text("Settings")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                Spacer()
            }

            // Providers
            VStack(alignment: .leading, spacing: 8) {
                Text("Providers")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(ProviderConfig.all) { config in
                    let status = manager.status(for: config.id)
                    HStack {
                        Image(systemName: status != .notInstalled ? "checkmark.square.fill" : "square")
                            .foregroundColor(status != .notInstalled ? config.tintColor : .secondary)
                            .font(.body)

                        Text(config.name)
                            .foregroundColor(.white)

                        Spacer()

                        Text(status != .notInstalled ? "detected" : "not found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider().opacity(0.3)

            // Refresh interval
            HStack {
                Text("Refresh every")
                    .foregroundColor(.white)
                Spacer()
                Picker("", selection: $refreshInterval) {
                    Text("1 min").tag(60.0)
                    Text("2 min").tag(120.0)
                    Text("5 min").tag(300.0)
                    Text("Manual").tag(0.0)
                }
                .frame(width: 100)
                .onChange(of: refreshInterval) { _, newValue in
                    if newValue > 0 {
                        manager.setRefreshInterval(newValue)
                    } else {
                        manager.stopPolling()
                    }
                }
            }

            // Launch at login
            Toggle("Launch at login", isOn: $launchAtLogin)
                .foregroundColor(.white)
                .onChange(of: launchAtLogin) { _, newValue in
                    // TODO: Use SMAppService.mainApp to register/unregister
                }

            Spacer()

            // Version
            HStack {
                Text("v0.1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .frame(width: 280, height: 400)
        .environment(\.colorScheme, .dark)
    }
}
```

**Step 3: Wire everything into PopoverView**

Update `PopoverView.swift` to include all sections:

```swift
import SwiftUI

struct PopoverView: View {
    @ObservedObject var manager: ProviderManager
    @State private var showSettings = false

    var body: some View {
        if showSettings {
            SettingsView(manager: manager, isPresented: $showSettings)
                .transition(.move(edge: .trailing))
        } else {
            mainView
                .transition(.move(edge: .leading))
        }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            // Section 1: Hero Moon
            if let snapshot = manager.selectedSnapshot,
               let config = manager.selectedConfig {
                HeroMoonView(snapshot: snapshot, config: config)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "moon.zzz")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No providers detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 24)
            }

            Divider().opacity(0.3)

            // Section 2: Provider Switcher
            ProviderSwitcher(manager: manager)

            Divider().opacity(0.3)

            // Section 3: Star Field + Summary
            if let snapshot = manager.selectedSnapshot {
                StarFieldView(
                    dailyUsage: snapshot.dailyUsage,
                    tintColor: manager.selectedConfig?.tintColor ?? .white
                )

                UsageSummaryView(dailyUsage: snapshot.dailyUsage)
            }

            Spacer()

            Divider().opacity(0.3)

            // Section 4: Footer
            FooterView(manager: manager, showSettings: $showSettings)
        }
        .frame(width: 280, height: 400)
        .background(.ultraThinMaterial.opacity(0.9))
        .environment(\.colorScheme, .dark)
    }
}
```

**Step 4: Build and verify**

Run: `swift build`
Expected: Compiles. Full popover with all four sections.

**Step 5: Commit**

```bash
git add Sources/Wane/UI/
git commit -m "feat: complete popover with footer, settings panel, and all sections wired"
```

---

## Task 14: Wire AppDelegate to ProviderManager

**Files:**
- Modify: `Sources/Wane/App/AppDelegate.swift`

**Step 1: Update AppDelegate to initialize and connect everything**

```swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let manager = ProviderManager()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register providers
        manager.registerProvider(ClaudeProvider())
        manager.registerProvider(CursorProvider())
        manager.registerProvider(CodexProvider())

        // Set up status bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = MoonRenderer.render(percentage: 100, tintColor: .white)
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Set up popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(manager: manager)
        )

        // Observe manager changes to update status bar icon
        manager.$selectedProviderId
            .combineLatest(manager.$snapshots)
            .receive(on: RunLoop.main)
            .sink { [weak self] selectedId, snapshots in
                self?.updateStatusBarIcon(selectedId: selectedId, snapshots: snapshots)
            }
            .store(in: &cancellables)

        // Detect providers and start fetching
        Task { @MainActor in
            await manager.detectProviders()
            await manager.refreshAll()
            manager.startPolling()
        }
    }

    private func updateStatusBarIcon(selectedId: String?, snapshots: [String: UsageSnapshot]) {
        guard let id = selectedId,
              let snapshot = snapshots[id],
              let config = ProviderConfig.all.first(where: { $0.id == id }) else {
            statusItem.button?.image = MoonRenderer.render(percentage: 100, tintColor: .white)
            return
        }

        statusItem.button?.image = MoonRenderer.render(
            percentage: snapshot.remainingPercentage,
            tintColor: NSColor(config.tintColor)
        )
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!

        if event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Wane", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Reset so left-click still shows popover
    }

    @objc private func refresh() {
        Task { @MainActor in
            await manager.refreshAll()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

**Step 2: Add Combine import to Package.swift if needed**

Combine is included in macOS SDK, no package dependency needed.

**Step 3: Build and run end-to-end**

Run: `swift build && swift run`
Expected: App launches, detects providers, fetches usage, moon icon updates to reflect real data.

**Step 4: Commit**

```bash
git add Sources/Wane/App/AppDelegate.swift
git commit -m "feat: wire AppDelegate to ProviderManager with live data and icon updates"
```

---

## Task 15: Polish & Packaging

**Files:**
- Create: `Scripts/build.sh`
- Create: `Scripts/package_app.sh`

**Step 1: Create build script**

```bash
#!/bin/bash
set -euo pipefail
swift build -c release
echo "Build complete: $(swift build -c release --show-bin-path)/Wane"
```

**Step 2: Create packaging script**

```bash
#!/bin/bash
set -euo pipefail

APP_NAME="Wane"
BIN_PATH=$(swift build -c release --show-bin-path)

# Create .app bundle
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"
cp "$BIN_PATH/$APP_NAME" "$APP_NAME.app/Contents/MacOS/"
cp Sources/Wane/Resources/Info.plist "$APP_NAME.app/Contents/"

# Ad-hoc sign
codesign --force --sign - "$APP_NAME.app"

echo "Packaged: $APP_NAME.app"
```

**Step 3: Make scripts executable and verify build**

```bash
chmod +x Scripts/build.sh Scripts/package_app.sh
./Scripts/build.sh
```

Expected: Release build succeeds.

**Step 4: Commit**

```bash
git add Scripts/ Sources/Wane/Resources/Info.plist
git commit -m "feat: add build and packaging scripts for .app bundle"
```

---

## Dependency Graph

```
Task 1: Scaffold ─────────────────────────┐
Task 2: Models ──────────────────────┐     │
Task 3: TokenFormatter ──────────┐   │     │
Task 4: Claude Provider ─────┐   │   │     │
Task 5: Codex Provider ──┐   │   │   │     │
Task 6: Cursor Provider ─┤   │   │   │     │
                          │   │   │   │     │
Task 7: ProviderManager ─┴───┴───┘   │     │
                          │           │     │
Task 8: MoonRenderer ────┤           │     │
Task 9: HeroMoonView ────┤           │     │
Task 10: ProviderSwitcher ┤          │     │
Task 11: StarFieldView ──┤───────────┘     │
Task 12: UsageSummaryView ┤               │
Task 13: Footer+Settings ─┤               │
                           │               │
Task 14: Wire AppDelegate ┴───────────────┘
Task 15: Build & Package
```

**Tasks 2, 3 can be done in parallel.**
**Tasks 4, 5, 6 can be done in parallel** (all depend on Task 2).
**Tasks 8, 9, 10, 11, 12, 13 can be partially parallelized** (all depend on Task 7 + Task 3).
