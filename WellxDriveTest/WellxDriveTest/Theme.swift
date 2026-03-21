import SwiftUI

enum Theme {
    static let background = Color(red: 8/255, green: 14/255, blue: 30/255)
    static let surface = Color(red: 14/255, green: 22/255, blue: 44/255)
    static let surfaceLight = Color(red: 22/255, green: 32/255, blue: 58/255)
    static let accent = Color(red: 0, green: 230/255, blue: 118/255)
    static let accentDim = Color(red: 0, green: 230/255, blue: 118/255).opacity(0.3)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.35)

    static let severityLow = Color(red: 76/255, green: 175/255, blue: 80/255)
    static let severityMedium = Color(red: 255/255, green: 193/255, blue: 7/255)
    static let severityHigh = Color(red: 255/255, green: 87/255, blue: 34/255)
    static let severityCritical = Color(red: 244/255, green: 67/255, blue: 54/255)

    static let sensorFont = Font.system(size: 11, design: .monospaced)
    static let monoSmall = Font.system(size: 10, design: .monospaced)

    static func scoreColor(for score: Double) -> Color {
        if score >= 80 { return Color(red: 0, green: 230/255, blue: 118/255) }
        if score >= 60 { return Color(red: 255/255, green: 193/255, blue: 7/255) }
        if score >= 40 { return Color(red: 255/255, green: 152/255, blue: 0/255) }
        return Color(red: 244/255, green: 67/255, blue: 54/255)
    }

    static func riskLabel(for score: Double) -> String {
        if score >= 80 { return "LOW RISK" }
        if score >= 60 { return "MODERATE" }
        if score >= 40 { return "HIGH RISK" }
        return "CRITICAL"
    }
}
