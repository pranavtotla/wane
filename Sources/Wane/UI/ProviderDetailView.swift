#if canImport(SwiftUI)
import SwiftUI

struct ProviderDetailView: View {
    let snapshot: UsageSnapshot
    let config: ProviderConfig
    let lastRefresh: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Provider header
            HStack(alignment: .firstTextBaseline) {
                Text(config.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                if let plan = snapshot.planName {
                    Text(plan)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(config.tintColor.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(config.tintColor.opacity(0.12))
                        )
                }

                Spacer()

                if let lastRefresh {
                    Text(lastRefresh.timeAgoShort)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Session card
            sessionCard

            // Extra usage card
            if snapshot.extraUsageLimit != nil || snapshot.extraUsageSpent != nil {
                extraUsageCard
            }

            // Token usage card
            tokenUsageCard
        }
        .padding(.bottom, 8)
    }

    // MARK: - Session

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(snapshot.remainingPercentage))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(percentageColor)

                Text("remaining")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()

                if let resetsAt = snapshot.resetsAt {
                    Label(resetsAt.relativeDescription, systemImage: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }

            UsageBar(
                percentage: snapshot.remainingPercentage,
                tintColor: config.tintColor
            )
        }
        .cardStyle()
    }

    private var percentageColor: Color {
        let pct = snapshot.remainingPercentage
        if pct > 60 { return config.tintColor }
        if pct > 30 { return Color(hex: 0xD4A054) }
        if pct > 10 { return Color(hex: 0xC46B3A) }
        return Color(hex: 0xB54444)
    }

    // MARK: - Extra Usage

    private var extraUsageCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            let spent = snapshot.extraUsageSpent ?? 0
            let limit = snapshot.extraUsageLimit ?? 0
            let pct = limit > 0 ? min(100, (spent / limit) * 100) : 0

            HStack(alignment: .firstTextBaseline) {
                Text("Extra Usage")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                Text("$\(String(format: "%.2f", spent))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))

                Text("/ $\(String(format: "%.0f", limit))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            UsageBar(
                percentage: 100 - pct,
                tintColor: .blue
            )
        }
        .cardStyle()
    }

    // MARK: - Token Usage

    private var tokenUsageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tokens")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

            HStack(spacing: 0) {
                tokenColumn(label: "Today", count: snapshot.todayTokens)
                tokenDivider
                tokenColumn(label: "7 days", count: snapshot.last7DaysTokens)
                tokenDivider
                tokenColumn(label: "30 days", count: snapshot.last30DaysTokens)
            }
        }
        .cardStyle()
    }

    private func tokenColumn(label: String, count: Int) -> some View {
        VStack(spacing: 2) {
            Text(TokenFormatter.compact(count))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .help(TokenFormatter.exact(count) + " tokens")

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private var tokenDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 28)
    }
}

// MARK: - Card Style

extension View {
    func cardStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
            )
            .padding(.horizontal, 12)
    }
}

// MARK: - Usage Bar

struct UsageBar: View {
    let percentage: Double
    let tintColor: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.08))

                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: max(0, geometry.size.width * CGFloat(percentage / 100)))
            }
        }
        .frame(height: 5)
    }

    private var barColor: Color {
        if percentage > 60 { return tintColor }
        if percentage > 30 { return Color(hex: 0xD4A054) }
        if percentage > 10 { return Color(hex: 0xC46B3A) }
        return Color(hex: 0xB54444)
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
#endif
