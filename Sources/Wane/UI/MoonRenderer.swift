#if canImport(AppKit)
import AppKit
import CoreGraphics

enum MoonRenderer {
    static func render(percentage: Double, tintColor: NSColor, size: CGFloat = 14) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2 - 1

            if percentage < 10 {
                let glowColor = NSColor(red: 0.71, green: 0.27, blue: 0.27, alpha: 0.12)
                context.setFillColor(glowColor.cgColor)
                context.fillEllipse(in: rect.insetBy(dx: -1, dy: -1))
            }

            let moonColor = phaseColor(percentage: percentage, tint: tintColor)
            context.setFillColor(moonColor.cgColor)
            context.fillEllipse(
                in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )

            let shadowFraction = 1.0 - (percentage / 100.0)
            if shadowFraction > 0.01 {
                context.saveGState()
                let circleRect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.addEllipse(in: circleRect)
                context.clip()

                let shadowColor = NSColor(white: 0.08, alpha: 0.92)
                context.setFillColor(shadowColor.cgColor)

                let shadowWidth = radius * 2 * min(1, shadowFraction * 2)
                let shadowRect = CGRect(
                    x: center.x + radius - shadowWidth,
                    y: center.y - radius,
                    width: shadowWidth,
                    height: radius * 2
                )
                context.fillEllipse(in: shadowRect)
                context.restoreGState()
            }

            return true
        }

        image.isTemplate = false
        return image
    }

    private static func phaseColor(percentage: Double, tint: NSColor) -> NSColor {
        let baseColor: NSColor
        switch percentage {
        case 60.1...:
            baseColor = NSColor(red: 0.91, green: 0.89, blue: 0.87, alpha: 1)
        case 35...60:
            baseColor = NSColor(red: 0.83, green: 0.63, blue: 0.33, alpha: 1)
        case 10..<35:
            baseColor = NSColor(red: 0.77, green: 0.42, blue: 0.23, alpha: 1)
        default:
            baseColor = NSColor(red: 0.71, green: 0.27, blue: 0.27, alpha: 1)
        }

        return baseColor.blended(withFraction: 0.15, of: tint) ?? baseColor
    }
}
#endif
