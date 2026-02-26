#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit

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
            Text(isSelected ? "▸" : " ")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 12)

            Text(config.name)
                .font(.system(.body, weight: isSelected ? .semibold : .regular))
                .foregroundColor(status == .needsReauth ? .secondary : .white)

            Spacer()

            if let snapshot {
                Image(
                    nsImage: MoonRenderer.render(
                        percentage: snapshot.remainingPercentage,
                        tintColor: NSColor(hex: config.tintHex),
                        size: 12
                    )
                )
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
#endif
