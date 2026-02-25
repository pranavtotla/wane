import Foundation

enum StarFieldViewModel {
    static func brightnessLevels(for counts: [Int], average: Double) -> [Int] {
        guard !counts.isEmpty else { return [] }
        let avg = average > 0 ? average : 1
        return counts.map { count in
            let ratio = Double(count) / avg
            switch ratio {
            case ..<0.1: return 0
            case ..<0.6: return 1
            case ..<1.4: return 2
            case ..<2.5: return 3
            default: return 4
            }
        }
    }

    static func padTo30Days(_ usage: [DailyUsage]) -> [DailyUsage] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var byDay: [String: Int] = [:]

        for item in usage {
            byDay[formatter.string(from: item.date)] = item.tokenCount
        }

        return (0..<30).map { index in
            let dayOffset = -(29 - index)
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            let key = formatter.string(from: date)
            return DailyUsage(date: date, tokenCount: byDay[key] ?? 0)
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

struct StarFieldView: View {
    let dailyUsage: [DailyUsage]
    let tintColor: Color

    private let columns = 6
    private let rows = 5

    var body: some View {
        let padded = StarFieldViewModel.padTo30Days(dailyUsage)
        let counts = padded.map(\.tokenCount)
        let average = counts.isEmpty ? 0 : Double(counts.reduce(0, +)) / Double(counts.count)
        let levels = StarFieldViewModel.brightnessLevels(for: counts, average: average)

        VStack(spacing: 8) {
            Grid(horizontalSpacing: 12, verticalSpacing: 8) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            if index < padded.count {
                                StarDot(
                                    level: levels[index],
                                    isToday: index == padded.count - 1,
                                    tintColor: tintColor,
                                    date: padded[index].date,
                                    tokenCount: padded[index].tokenCount
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

struct StarDot: View {
    let level: Int
    let isToday: Bool
    let tintColor: Color
    let date: Date
    let tokenCount: Int

    @State private var isHovering = false
    @State private var pulseOpacity: Double = 0.7

    private var dotSize: CGFloat {
        switch level {
        case 0, 1: return 3
        case 2: return 4
        default: return 5
        }
    }

    private var dotOpacity: Double {
        switch level {
        case 0: return 0.15
        case 1: return 0.35
        case 2: return 0.6
        case 3: return 0.85
        default: return 1
        }
    }

    var body: some View {
        ZStack {
            if level == 4 {
                Circle()
                    .fill(tintColor.opacity(0.3))
                    .frame(width: dotSize + 4, height: dotSize + 4)
                    .blur(radius: 2)
            }

            if isToday {
                ZStack {
                    Circle()
                        .stroke(tintColor.opacity(dotOpacity), lineWidth: 1)
                        .frame(width: dotSize + 2, height: dotSize + 2)
                    Circle()
                        .fill(tintColor.opacity(pulseOpacity))
                        .frame(width: max(dotSize - 1, 1), height: max(dotSize - 1, 1))
                }
                .onAppear {
                    guard tokenCount > 0 else { return }
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        pulseOpacity = 1
                    }
                }
            } else {
                Circle()
                    .fill(tintColor.opacity(dotOpacity))
                    .frame(width: dotSize, height: dotSize)
            }
        }
        .scaleEffect(isHovering ? 1.3 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .frame(width: 12, height: 12)
        .onHover { hovering in
            isHovering = hovering
        }
        .popover(isPresented: .init(get: { isHovering }, set: { isHovering = $0 })) {
            StarTooltip(date: date, tokenCount: tokenCount)
        }
    }
}

struct StarTooltip: View {
    let date: Date
    let tokenCount: Int

    var body: some View {
        Text("\(date.formatted(.dateTime.month(.abbreviated).day())) · \(TokenFormatter.exact(tokenCount))")
            .font(.system(.caption2, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }
}
#endif
