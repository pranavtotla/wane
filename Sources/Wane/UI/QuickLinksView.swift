#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit

struct QuickLinksView: View {
    let selectedConfig: ProviderConfig?

    var body: some View {
        VStack(spacing: 0) {
            if let config = selectedConfig {
                QuickLinkRow(
                    icon: "chart.bar",
                    label: "Usage Dashboard",
                    action: { openDashboard(for: config) }
                )
                QuickLinkRow(
                    icon: "bolt.horizontal",
                    label: "Status Page",
                    action: { openStatusPage(for: config) }
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func openDashboard(for config: ProviderConfig) {
        let url: String
        switch config.id {
        case "claude": url = "https://claude.ai/settings/usage"
        case "cursor": url = "https://cursor.com/dashboard?tab=usage"
        case "codex": url = "https://chatgpt.com/codex/settings/usage"
        default: return
        }
        NSWorkspace.shared.open(URL(string: url)!)
    }

    private func openStatusPage(for config: ProviderConfig) {
        let url: String
        switch config.id {
        case "claude": url = "https://status.anthropic.com"
        case "cursor": url = "https://status.cursor.com"
        case "codex": url = "https://status.openai.com"
        default: return
        }
        NSWorkspace.shared.open(URL(string: url)!)
    }
}

struct QuickLinkRow: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(isHovering ? Color.white.opacity(0.06) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            action()
        }
    }
}
#endif
