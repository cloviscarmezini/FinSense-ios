// Sources/FinSense/DesignSystem/ColorTokens.swift
import SwiftUI

extension Color {
    public init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 59, 130, 246)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

public struct LiquidColors {
    public static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#0B0F17") : Color(hex: "#F1F5F9")
    }

    public static func surfaceGlass(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#1E293B").opacity(0.55) : Color.white.opacity(0.65)
    }

    public static func borderSpecular(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.85)
    }

    public static func income(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#10B981") : Color(hex: "#059669")
    }

    public static func expense(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#F43F5E") : Color(hex: "#DC2626")
    }

    public static func pending(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#F59E0B") : Color(hex: "#D97706")
    }

    public static func investment(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#818CF8") : Color(hex: "#4F46E5")
    }

    public static func ai(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#38BDF8") : Color(hex: "#0284C7")
    }
}
