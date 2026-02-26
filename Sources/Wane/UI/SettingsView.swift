#if canImport(SwiftUI)
import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: ProviderManager
    @Binding var isPresented: Bool
    @AppStorage("refreshInterval") private var refreshInterval: Double = 120
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Providers")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(ProviderConfig.all) { config in
                    let status = manager.status(for: config.id)
                    HStack {
                        Image(systemName: status != .notInstalled ? "checkmark.square.fill" : "square")
                            .foregroundColor(status != .notInstalled ? config.tintColor : .secondary)

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

            Toggle("Launch at login", isOn: $launchAtLogin)
                .foregroundColor(.white)

            Spacer()

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
#endif
