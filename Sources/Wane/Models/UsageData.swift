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
}
