import Foundation

struct ProviderConfig: Identifiable, Equatable {
    let id: String
    let name: String
    let tintHex: UInt
    let iconSymbol: String

    static let claude = ProviderConfig(id: "claude", name: "Claude", tintHex: 0xD97757, iconSymbol: "sparkles")
    static let cursor = ProviderConfig(id: "cursor", name: "Cursor", tintHex: 0x7B61FF, iconSymbol: "cursorarrow.rays")
    static let codex = ProviderConfig(id: "codex", name: "Codex", tintHex: 0x10A37F, iconSymbol: "chevron.left.forwardslash.chevron.right")

    static let all: [ProviderConfig] = [.codex, .claude, .cursor]
}

#if canImport(SwiftUI)
import SwiftUI

extension ProviderConfig {
    var tintColor: Color {
        Color(hex: tintHex)
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
#endif

#if canImport(AppKit)
import AppKit

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
