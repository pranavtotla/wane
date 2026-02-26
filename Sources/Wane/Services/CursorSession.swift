import Foundation

enum CursorSession {
    private static let sessionDir = NSString(
        "~/Library/Application Support/Wane"
    ).expandingTildeInPath

    private static var sessionPath: String {
        (sessionDir as NSString).appendingPathComponent("cursor-session.json")
    }

    static func load() -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: sessionPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cookie = json["cookieHeader"] as? String,
              !cookie.isEmpty
        else {
            return nil
        }
        return cookie
    }

    static func save(cookieHeader: String) {
        let json: [String: Any] = [
            "cookieHeader": cookieHeader,
            "savedAt": ISO8601DateFormatter().string(from: Date())
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }

        let fm = FileManager.default
        if !fm.fileExists(atPath: sessionDir) {
            try? fm.createDirectory(atPath: sessionDir, withIntermediateDirectories: true)
        }
        try? data.write(to: URL(fileURLWithPath: sessionPath))
    }

    static func clear() {
        try? FileManager.default.removeItem(atPath: sessionPath)
    }

    static var hasSavedSession: Bool {
        load() != nil
    }
}
