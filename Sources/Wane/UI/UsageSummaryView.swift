#if canImport(SwiftUI)
import SwiftUI

enum UsageSummaryCalculator {
    static func todayCount(_ padded: [DailyUsage]) -> Int {
        padded.last?.tokenCount ?? 0
    }

    static func lastNDaysCount(_ padded: [DailyUsage], n: Int) -> Int {
        padded.suffix(n).reduce(0) { $0 + $1.tokenCount }
    }
}

struct UsageSummaryView: View {
    let dailyUsage: [DailyUsage]

    var body: some View {
        let padded = StarFieldViewModel.padTo30Days(dailyUsage)
        let today = UsageSummaryCalculator.todayCount(padded)
        let sevenDay = UsageSummaryCalculator.lastNDaysCount(padded, n: 7)
        let thirtyDay = UsageSummaryCalculator.lastNDaysCount(padded, n: 30)

        HStack(spacing: 16) {
            SummaryItem(label: "Today", count: today)
            SummaryItem(label: "7d", count: sevenDay)
            SummaryItem(label: "30d", count: thirtyDay)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

struct SummaryItem: View {
    let label: String
    let count: Int
    @State private var showExact = false

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(.caption2))
                .foregroundColor(.secondary)

            Text(showExact ? TokenFormatter.exact(count) : TokenFormatter.compact(count))
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundColor(.white)
                .contentTransition(.numericText())
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                showExact = hovering
            }
        }
    }
}
#endif
