#if canImport(SwiftUI)
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
            ProviderSwitcher(manager: manager)
            Divider().opacity(0.3)

            if let snapshot = manager.selectedSnapshot {
                StarFieldView(
                    dailyUsage: snapshot.dailyUsage,
                    tintColor: manager.selectedConfig?.tintColor ?? .white
                )
                UsageSummaryView(dailyUsage: snapshot.dailyUsage)
            }

            Spacer()
            Divider().opacity(0.3)
            FooterView(manager: manager, showSettings: $showSettings)
        }
        .frame(width: 280, height: 400)
        .background(.ultraThinMaterial.opacity(0.9))
        .environment(\.colorScheme, .dark)
    }
}
#endif
