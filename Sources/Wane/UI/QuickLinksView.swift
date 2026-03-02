#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit

struct QuickLinksView: View {
    let selectedConfig: ProviderConfig?

    var body: some View {
        VStack(spacing: 0) {
            if let config = selectedConfig {
                MenuRow(
                    icon: "chart.bar",
                    label: "Usage Dashboard",
                    action: { openDashboard(for: config) }
                )
                MenuRow(
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

#endif
