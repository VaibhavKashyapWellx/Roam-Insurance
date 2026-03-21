import SwiftUI

struct ScoreRing: View {
    let score: Double
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    private var progress: Double { score / 100.0 }
    private var color: Color { Theme.scoreColor(for: score) }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Theme.surfaceLight, lineWidth: size * 0.06)

            // Score arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.3), color],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * animatedProgress)
                    ),
                    style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.5), radius: 8)

            // Score text
            VStack(spacing: 2) {
                Text("\(Int(score))")
                    .font(.system(size: size * 0.28, weight: .bold, design: .monospaced))
                    .foregroundColor(color)

                Text(Theme.riskLabel(for: score))
                    .font(.system(size: size * 0.08, weight: .semibold))
                    .foregroundColor(color.opacity(0.8))
                    .tracking(1.5)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newValue / 100.0
            }
        }
    }
}
