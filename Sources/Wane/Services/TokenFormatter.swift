import Foundation

enum TokenFormatter {
    static func compact(_ count: Int) -> String {
        switch count {
        case ..<1_000:
            return "\(count)"
        case ..<1_000_000:
            return formatUnit(Double(count) / 1_000, suffix: "K")
        case ..<1_000_000_000:
            return formatUnit(Double(count) / 1_000_000, suffix: "M")
        default:
            return formatUnit(Double(count) / 1_000_000_000, suffix: "B")
        }
    }

    static func exact(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private static func formatUnit(_ value: Double, suffix: String) -> String {
        if value >= 999.95 {
            switch suffix {
            case "K":
                return formatUnit(value / 1_000, suffix: "M")
            case "M":
                return formatUnit(value / 1_000, suffix: "B")
            default:
                break
            }
        }

        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))\(suffix)"
        }
        return String(format: "%.1f%@", rounded, suffix)
    }
}
