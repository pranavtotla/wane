#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit

struct FooterView: View {
    @ObservedObject var manager: ProviderManager
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            MenuRow(icon: "gearshape", label: "Settings...") {
                showSettings = true
            }
            MenuRow(icon: "info.circle", label: "About Wane") {
                // TODO: about panel
            }
            MenuRow(icon: "xmark.circle", label: "Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MenuRow: View {
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

extension Date {
    var timeAgoShort: String {
        let seconds = max(0, Int(-timeIntervalSinceNow))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3_600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3_600)h ago"
    }
}
#endif
