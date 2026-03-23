import SwiftUI

struct CategoryScoreBar: View {
    let category: EventCategory
    let score: Double
    let count: Int

    private var color: Color { Theme.scoreColor(for: score) }

    private var icon: String {
        switch category {
        case .braking: return "arrow.down.circle"
        case .acceleration: return "arrow.up.circle"
        case .cornering: return "arrow.turn.right.up"
        case .distraction: return "iphone"
        case .smoothness: return "waveform.path"
        case .context: return "clock"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 16)

            Text(category.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 68, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.surfaceLight)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * score / 100.0, height: 6)
                }
            }
            .frame(height: 6)

            Text("\(Int(score))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 28, alignment: .trailing)

            if count > 0 {
                Text("(\(count))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)
                    .frame(width: 24)
            } else {
                Spacer().frame(width: 24)
            }
        }
        .frame(height: 18)
    }
}
