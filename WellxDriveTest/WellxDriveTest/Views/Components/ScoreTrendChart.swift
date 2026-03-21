import SwiftUI

struct ScoreTrendChart: View {
    let points: [ScorePoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SCORE TREND (60s)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
                .tracking(1)

            GeometryReader { geo in
                if points.count >= 2 {
                    let minScore = (points.map(\.score).min() ?? 0)
                    let maxScore = (points.map(\.score).max() ?? 100)
                    let range = max(maxScore - minScore, 10)

                    ZStack {
                        // Grid lines
                        ForEach([0.25, 0.5, 0.75], id: \.self) { frac in
                            Path { path in
                                let y = geo.size.height * (1 - frac)
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: geo.size.width, y: y))
                            }
                            .stroke(Theme.surfaceLight, lineWidth: 0.5)
                        }

                        // Score line
                        Path { path in
                            for (i, point) in points.enumerated() {
                                let x = geo.size.width * Double(i) / Double(points.count - 1)
                                let y = geo.size.height * (1 - (point.score - minScore) / range)
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Theme.accent, lineWidth: 1.5)

                        // Gradient fill
                        Path { path in
                            for (i, point) in points.enumerated() {
                                let x = geo.size.width * Double(i) / Double(points.count - 1)
                                let y = geo.size.height * (1 - (point.score - minScore) / range)
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                            path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent.opacity(0.3), Theme.accent.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                } else {
                    Text("Collecting data...")
                        .font(Theme.monoSmall)
                        .foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(height: 70)
    }
}
