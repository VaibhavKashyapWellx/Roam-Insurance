import SwiftUI

enum Theme {
    // Light Wellx-inspired palette
    static let background = Color(red: 247/255, green: 248/255, blue: 252/255)
    static let surface = Color.white
    static let surfaceLight = Color(red: 235/255, green: 237/255, blue: 245/255)
    static let accent = Color(red: 75/255, green: 45/255, blue: 180/255)       // deep purple
    static let accentLight = Color(red: 120/255, green: 90/255, blue: 220/255)  // lighter purple
    static let accentDim = Color(red: 75/255, green: 45/255, blue: 180/255).opacity(0.12)
    static let textPrimary = Color(red: 20/255, green: 20/255, blue: 35/255)
    static let textSecondary = Color(red: 100/255, green: 105/255, blue: 125/255)
    static let textTertiary = Color(red: 155/255, green: 160/255, blue: 175/255)

    // Severity colors
    static let severityLow = Color(red: 76/255, green: 175/255, blue: 80/255)
    static let severityMedium = Color(red: 255/255, green: 167/255, blue: 38/255)
    static let severityHigh = Color(red: 255/255, green: 87/255, blue: 34/255)
    static let severityCritical = Color(red: 229/255, green: 57/255, blue: 53/255)

    // Coin colors
    static let coinGold = Color(red: 255/255, green: 193/255, blue: 7/255)
    static let coinPositive = Color(red: 46/255, green: 174/255, blue: 96/255)
    static let coinNegative = Color(red: 229/255, green: 57/255, blue: 53/255)

    // Score gradient (blue → purple cloud)
    static let scoreGradientStart = Color(red: 100/255, green: 120/255, blue: 230/255)
    static let scoreGradientEnd = Color(red: 75/255, green: 45/255, blue: 180/255)

    // Card styling
    static let cardShadow = Color.black.opacity(0.04)
    static let cardBorder = Color(red: 220/255, green: 225/255, blue: 235/255)

    static let sensorFont = Font.system(size: 11, design: .monospaced)
    static let monoSmall = Font.system(size: 10, design: .monospaced)

    static func scoreColor(for score: Double) -> Color {
        if score >= 80 { return Color(red: 46/255, green: 174/255, blue: 96/255) }
        if score >= 60 { return Color(red: 255/255, green: 167/255, blue: 38/255) }
        if score >= 40 { return Color(red: 255/255, green: 87/255, blue: 34/255) }
        return Color(red: 229/255, green: 57/255, blue: 53/255)
    }

    static func riskLabel(for score: Double) -> String {
        if score >= 80 { return "Excellent" }
        if score >= 60 { return "Good" }
        if score >= 40 { return "Needs improvement" }
        return "Poor"
    }
}
