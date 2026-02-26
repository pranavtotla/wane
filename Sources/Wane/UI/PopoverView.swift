#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit

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
            ProviderTabBar(manager: manager)

            separator

            // Provider detail with content transition keyed on selected provider
            Group {
                if let snapshot = manager.selectedSnapshot,
                   let config = manager.selectedConfig {
                    ProviderDetailView(
                        snapshot: snapshot,
                        config: config,
                        lastRefresh: manager.lastRefresh
                    )
                    .id(config.id)
                    .transition(.opacity)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No providers detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Install Claude, Codex, or Cursor to get started")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }
            .animation(.easeOut(duration: 0.15), value: manager.selectedProviderId)

            separator

            QuickLinksView(selectedConfig: manager.selectedConfig)

            separator

            FooterView(manager: manager, showSettings: $showSettings)
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.colorScheme, .dark)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }
}
#endif
