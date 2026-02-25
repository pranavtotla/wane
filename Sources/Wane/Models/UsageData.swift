import Foundation

enum MoonPhase: Equatable {
    case full      // >85%
    case gibbous   // 60-85%
    case quarter   // 35-60%
    case crescent  // 10-35%
    case new       // <10%

    static func from(percentage: Double) -> MoonPhase {
        switch percentage {
        case 85.1...:
            return .full
        case 60...85:
            return .gibbous
        case 35..<60:
            return .quarter
        case 10..<35:
            return .crescent
        default:
            return .new
        }
    }

    enum Color: Equatable {
        case white
        case amber
        case orange
        case red
    }

    static func color(forPercentage percentage: Double) -> Color {
        switch percentage {
        case 60.1...:
            return .white
        case 35...60:
            return .amber
        case 10..<35:
            return .orange
        default:
            return .red
        }
    }
}

struct DailyUsage: Equatable {
    let date: Date
    let tokenCount: Int
}

struct UsageSnapshot: Equatable {
    let remainingPercentage: Double
    let resetsAt: Date?
    let dailyUsage: [DailyUsage]

    var moonPhase: MoonPhase {
        MoonPhase.from(percentage: remainingPercentage)
    }

    var moonColor: MoonPhase.Color {
        MoonPhase.color(forPercentage: remainingPercentage)
    }

    static let empty = UsageSnapshot(
        remainingPercentage: 100,
        resetsAt: nil,
        dailyUsage: []
    )
}
