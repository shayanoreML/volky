//
//  DesignTokens.swift
//  Volcy
//
//  Breeze Clinical Design System
//  Air-light, precise, supportive
//

import SwiftUI

// MARK: - Color Tokens

enum VolcyColor {
    // Base palette
    static let canvas = Color(hex: "#F7FAFC")      // Cloud - background
    static let surface = Color(hex: "#ECF2F7")     // Mist - cards
    static let textPrimary = Color(hex: "#111827") // Graphite - primary text
    static let textSecondary = Color(hex: "#374151") // Secondary text
    static let mint = Color(hex: "#69E3C6")        // Primary accent
    static let sky = Color(hex: "#6AB7FF")         // Secondary accent
    static let hairline = Color(hex: "#E2E8F0")    // Dividers, borders
    static let ash = Color(hex: "#E2E8F0")         // Ash - subtle borders

    // Semantic colors
    static let success = mint
    static let info = sky
    static let warning = Color(hex: "#F59E0B")
    static let error = Color(hex: "#EF4444")

    // Depth map colors
    static let depthLow = Color(hex: "#3B82F6")
    static let depthMid = Color(hex: "#8B5CF6")
    static let depthHigh = Color(hex: "#EC4899")
}

// MARK: - Spacing Tokens

enum VolcySpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let base: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Radius Tokens

enum VolcyRadius {
    static let card: CGFloat = 14
    static let button: CGFloat = 12
    static let pill: CGFloat = 999
    static let small: CGFloat = 8
}

// MARK: - Shadow Tokens

enum VolcyShadow {
    static let card: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) =
        (.black.opacity(0.08), 24, 0, 8)
    static let button: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) =
        (.black.opacity(0.06), 12, 0, 4)
}

// MARK: - Typography Tokens

enum VolcyTypography {
    // Font families
    static let uiFont = "SF Pro"           // UI elements
    static let headingFont = "Space Grotesk" // Headings
    static let monoFont = "JetBrains Mono"  // Numbers, metrics

    // Font sizes
    static let displaySize: CGFloat = 34
    static let h1Size: CGFloat = 28
    static let h2Size: CGFloat = 22
    static let h3Size: CGFloat = 18
    static let bodySize: CGFloat = 16
    static let captionSize: CGFloat = 14
    static let smallSize: CGFloat = 12

    // Line heights
    static let displayLineHeight: CGFloat = 41
    static let h1LineHeight: CGFloat = 34
    static let h2LineHeight: CGFloat = 28
    static let bodyLineHeight: CGFloat = 24
    static let captionLineHeight: CGFloat = 20
}

// MARK: - Chart Tokens

enum VolcyChart {
    static let strokeWidth: CGFloat = 1.5
    static let thickStrokeWidth: CGFloat = 2.0
    static let lineCap: CGLineCap = .round
    static let lineJoin: CGLineJoin = .round

    // Chart colors
    static let clarity = VolcyColor.mint
    static let redness = Color(hex: "#EF4444")
    static let diameter = VolcyColor.sky
    static let elevation = Color(hex: "#8B5CF6")
}

// MARK: - Animation Tokens

enum VolcyAnimation {
    static let fast: Double = 0.2
    static let normal: Double = 0.3
    static let slow: Double = 0.5
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
}

// MARK: - Helper Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(VolcyColor.surface)
            .cornerRadius(VolcyRadius.card)
            .shadow(
                color: VolcyShadow.card.color,
                radius: VolcyShadow.card.radius,
                x: VolcyShadow.card.x,
                y: VolcyShadow.card.y
            )
    }
}

extension View {
    func volcyCard() -> some View {
        modifier(CardStyle())
    }
}
