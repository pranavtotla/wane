import Foundation

struct DailyUsage: Equatable {
    let date: Date
    let tokenCount: Int
}

struct UsageSnapshot: Equatable {
    let remainingPercentage: Double
    let resetsAt: Date?
    let dailyUsage: [DailyUsage]
    let planName: String?
    let extraUsageSpent: Double?
    let extraUsageLimit: Double?

    static let empty = UsageSnapshot(
        remainingPercentage: 100,
        resetsAt: nil,
        dailyUsage: [],
        planName: nil,
        extraUsageSpent: nil,
        extraUsageLimit: nil
    )

    var todayTokens: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return dailyUsage
            .filter { calendar.isDate($0.date, inSameDayAs: today) }
            .reduce(0) { $0 + $1.tokenCount }
    }

    var last7DaysTokens: Int {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date()))!
        return dailyUsage
            .filter { $0.date >= sevenDaysAgo }
            .reduce(0) { $0 + $1.tokenCount }
    }

    var last30DaysTokens: Int {
        dailyUsage.reduce(0) { $0 + $1.tokenCount }
    }
}
