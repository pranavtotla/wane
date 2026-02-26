#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI

struct ProviderTabBar: View {
    @ObservedObject var manager: ProviderManager

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ProviderConfig.all) { config in
                let status = manager.status(for: config.id)
                let isSelected = manager.selectedProviderId == config.id

                if status != .notInstalled {
                    ProviderPill(
                        config: config,
                        isSelected: isSelected,
                        status: status
                    )
                    .onTapGesture {
                        manager.selectProvider(config.id)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct ProviderPill: View {
    let config: ProviderConfig
    let isSelected: Bool
    let status: ProviderStatus

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(config.tintColor)
                .frame(width: 7, height: 7)

            Text(config.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(isSelected ? config.tintColor.opacity(0.2) : (isHovering ? Color.white.opacity(0.06) : Color.clear))
        )
        .overlay(
            Capsule()
                .strokeBorder(isSelected ? config.tintColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .opacity(status == .needsReauth ? 0.5 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}
#endif
