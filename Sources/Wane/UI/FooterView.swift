#if canImport(SwiftUI)
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
        let seconds = max(0, Int(-timeIntervalSinceNow))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3_600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3_600)h ago"
    }
}
#endif
