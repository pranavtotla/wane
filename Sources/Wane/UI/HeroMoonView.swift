#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit

struct HeroMoonView: View {
    let snapshot: UsageSnapshot
    let config: ProviderConfig

    var body: some View {
        VStack(spacing: 6) {
            Image(
                nsImage: MoonRenderer.render(
                    percentage: snapshot.remainingPercentage,
                    tintColor: NSColor(hex: config.tintHex),
                    size: 48
                )
            )
            .frame(width: 48, height: 48)

            Text(config.name)
                .font(.system(.headline, design: .default, weight: .bold))
                .foregroundColor(.white)

            Text("\(Int(snapshot.remainingPercentage))% remaining")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundColor(moonColor)

            if let resetsAt = snapshot.resetsAt {
                Text("resets in \(resetsAt.relativeDescription)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private var moonColor: Color {
        switch MoonPhase.color(forPercentage: snapshot.remainingPercentage) {
        case .white: return Color(hex: 0xE8E4DF)
        case .amber: return Color(hex: 0xD4A054)
        case .orange: return Color(hex: 0xC46B3A)
        case .red: return Color(hex: 0xB54444)
        }
    }
}

extension Date {
    var relativeDescription: String {
        let interval = timeIntervalSinceNow
        guard interval > 0 else { return "now" }

        let hours = Int(interval) / 3_600
        let minutes = (Int(interval) % 3_600) / 60

        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

extension NSColor {
    convenience init(hex: UInt, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
#endif
