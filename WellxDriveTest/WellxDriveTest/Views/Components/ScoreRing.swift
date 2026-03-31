import SwiftUI

struct ScoreRing: View {
    let score: Double
    let size: CGFloat

    @State private var animatedScore: Double = 0
    @State private var glowPhase: Double = 0

    var body: some View {
        ZStack {
            // Radial gradient cloud background (Wellx style)
            ZStack {
                // Outer soft glow
                RadialGradient(
                    gradient: Gradient(colors: [
                        Theme.scoreGradientEnd.opacity(0.35),
                        Theme.scoreGradientStart.opacity(0.15),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: size * 0.05,
                    endRadius: size * 0.55
                )

                // Inner vibrant core
                RadialGradient(
                    gradient: Gradient(colors: [
                        Theme.scoreGradientEnd.opacity(0.7),
                        Theme.scoreGradientStart.opacity(0.4),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: size * 0.02,
                    endRadius: size * 0.35
                )

                // Noise-like cloud effect via overlapping circles
                ForEach(0..<6, id: \.self) { i in
                    let angle = Double(i) * 60.0
                    let offsetX = cos(angle * .pi / 180) * size * 0.08
                    let offsetY = sin(angle * .pi / 180) * size * 0.08
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Theme.scoreGradientEnd.opacity(0.25),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: size * 0.25
                            )
                        )
                        .frame(width: size * 0.5, height: size * 0.5)
                        .offset(x: offsetX, y: offsetY)
                        .blur(radius: size * 0.05)
                }
            }
            .frame(width: size, height: size)

            // Score text
            VStack(spacing: 2) {
                Text("\(Int(animatedScore))")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)

                Text(Theme.riskLabel(for: score))
                    .font(.system(size: size * 0.07, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedScore = score
            }
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedScore = newValue
            }
        }
    }
}
