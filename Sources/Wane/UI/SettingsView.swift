#if canImport(SwiftUI)
import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: ProviderManager
    @Binding var isPresented: Bool
    @AppStorage("refreshInterval") private var refreshInterval: Double = 120
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @State private var showCursorLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button(action: { isPresented = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Settings")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            separator

            // Providers
            VStack(alignment: .leading, spacing: 8) {
                Text("Providers")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ForEach(ProviderConfig.all) { config in
                    let status = manager.status(for: config.id)
                    HStack(spacing: 8) {
                        Image(systemName: statusIcon(for: status))
                            .font(.system(size: 14))
                            .foregroundColor(statusColor(for: status, config: config))

                        Text(config.name)
                            .font(.system(size: 13))
                            .foregroundColor(.white)

                        Spacer()

                        if config.id == "cursor" && status == .needsReauth {
                            Button("Sign in") {
                                showCursorLogin = true
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(config.tintColor)
                            .buttonStyle(.plain)
                        } else if config.id == "cursor" && CursorSession.hasSavedSession {
                            Button("Sign out") {
                                CursorSession.clear()
                                Task {
                                    await manager.refreshAll()
                                }
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                            .buttonStyle(.plain)
                        } else {
                            Text(statusLabel(for: status))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            separator.padding(.top, 12)

            // Refresh interval
            HStack {
                Text("Refresh every")
                    .font(.system(size: 13))
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
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Launch at login
            Toggle("Launch at login", isOn: $launchAtLogin)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            Spacer()

            separator

            HStack {
                Text("Wane v0.1.0")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showCursorLogin) {
            CursorLoginView(isPresented: $showCursorLogin) { cookieHeader in
                CursorSession.save(cookieHeader: cookieHeader)
                Task {
                    await manager.refreshAll()
                }
            }
        }
    }

    private func statusIcon(for status: ProviderStatus) -> String {
        switch status {
        case .ok: return "checkmark.circle.fill"
        case .needsReauth: return "exclamationmark.circle.fill"
        case .stale: return "clock.circle.fill"
        case .notInstalled: return "circle"
        }
    }

    private func statusColor(for status: ProviderStatus, config: ProviderConfig) -> Color {
        switch status {
        case .ok: return config.tintColor
        case .needsReauth: return .orange
        case .stale: return .yellow
        case .notInstalled: return .secondary.opacity(0.5)
        }
    }

    private func statusLabel(for status: ProviderStatus) -> String {
        switch status {
        case .ok: return "connected"
        case .needsReauth: return "needs sign in"
        case .stale: return "stale"
        case .notInstalled: return "not found"
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }
}
#endif
