import SwiftUI

struct EventRow: View {
    let event: DrivingEvent

    private var severityColor: Color {
        switch event.severity {
        case .low: return Theme.severityLow
        case .medium: return Theme.severityMedium
        case .high: return Theme.severityHigh
        case .critical: return Theme.severityCritical
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: event.timestamp)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.type.icon)
                .font(.system(size: 14))
                .foregroundColor(severityColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.type.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textPrimary)

                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(Theme.monoSmall)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()

            Text(event.severity.label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(severityColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(severityColor.opacity(0.15))
                .cornerRadius(3)

            Text(timeString)
                .font(Theme.monoSmall)
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
