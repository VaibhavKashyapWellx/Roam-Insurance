import SwiftUI

struct TripView: View {
    @ObservedObject var tripManager: TripManager

    @State private var coinAnimations: [CoinAnimation] = []
    @State private var lastCoinEventCount = 0

    private var durationString: String {
        let total = Int(tripManager.tripDuration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var speedKmh: String {
        let speed = tripManager.currentReading.speed
        if speed < 0 { return "--" }
        return String(format: "%.0f", speed * 3.6)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if tripManager.isTripping {
                    activeTripView
                } else {
                    idleView
                }
            }
        }
        .background(Theme.background)
        .onChange(of: tripManager.coinEvents.count) { _, newCount in
            if newCount > lastCoinEventCount, let latest = tripManager.coinEvents.first {
                triggerCoinAnimation(for: latest)
            }
            lastCoinEventCount = newCount
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("WellxDrive")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                if tripManager.isTripping {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.coinPositive)
                            .frame(width: 6, height: 6)
                        Text("Recording trip")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                    }
                } else if tripManager.isMonitoring {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.severityMedium)
                            .frame(width: 6, height: 6)
                        Text("Auto-detect on")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            Spacer()
            if tripManager.isTripping {
                Text(durationString)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }

    // MARK: - Active Trip

    private var activeTripView: some View {
        VStack(spacing: 16) {
            // Score section with cloud
            VStack(spacing: 4) {
                Text("Drive Score")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.textSecondary)

                ScoreRing(score: tripManager.currentScore, size: 200)
            }
            .padding(.vertical, 8)

            // XCoin display with floating animations
            xCoinSection
                .padding(.horizontal, 20)

            // Stop button
            Button(action: { tripManager.endTrip() }) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13))
                    Text("End Trip")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.severityCritical)
                .cornerRadius(14)
            }
            .padding(.horizontal, 20)

            // Stats cards (Wellx-style 2x2 grid)
            statsGrid
                .padding(.horizontal, 20)

            // Category scores in cards
            categoryCardsSection
                .padding(.horizontal, 20)

            // Live events
            liveEventsSection
                .padding(.horizontal, 20)

            Spacer(minLength: 30)
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Drive Score")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.textSecondary)

                ScoreRing(score: 100, size: 220)
            }
            .padding(.top, 8)

            // Description card
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Drive Score reflects how safely you drive — built from braking patterns, acceleration, phone use, and more.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .lineSpacing(3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.cardBorder, lineWidth: 1)
                    .background(Theme.surface.cornerRadius(14))
            )
            .padding(.horizontal, 20)

            // XCoin info card
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.coinGold)
                    Text("XCoins")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
                Text("Earn up to 30 XCoins per trip by driving safely. You start with 20 — keep them by avoiding harsh events!")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.cardBorder, lineWidth: 1)
                    .background(Theme.surface.cornerRadius(14))
            )
            .padding(.horizontal, 20)

            // Start / Auto-detect buttons
            VStack(spacing: 10) {
                Button(action: { tripManager.startTrip() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                        Text("Start Trip")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent)
                    .cornerRadius(14)
                }

                Button(action: {
                    if tripManager.isMonitoring {
                        tripManager.stopMonitoring()
                    } else {
                        tripManager.startMonitoring()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: tripManager.isMonitoring ? "location.slash.fill" : "location.fill")
                            .font(.system(size: 13))
                        Text(tripManager.isMonitoring ? "Stop Auto-Detect" : "Auto-Detect Drive")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(tripManager.isMonitoring ? Theme.severityMedium : Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(tripManager.isMonitoring ? Theme.severityMedium : Theme.accent, lineWidth: 1.5)
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 30)
        }
    }

    // MARK: - XCoin Section

    private var xCoinSection: some View {
        ZStack {
            // Coin card
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.coinGold)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.1f", tripManager.xCoins))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                            .contentTransition(.numericText())
                        Text("XCoins")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                Spacer()

                // Mini progress to 30
                VStack(alignment: .trailing, spacing: 4) {
                    Text("/ 30 max")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.surfaceLight)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.coinGold, Theme.coinPositive],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * max(0, min(1, tripManager.xCoins / 30.0)))
                        }
                    }
                    .frame(width: 80, height: 6)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surface)
                    .shadow(color: Theme.cardShadow, radius: 8, y: 2)
            )

            // Floating coin animations
            ForEach(coinAnimations) { anim in
                CoinAnimationView(animation: anim)
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                metricCard(
                    title: "Speed",
                    value: speedKmh,
                    unit: "km/h",
                    icon: "speedometer",
                    iconColor: Theme.accent
                )
                metricCard(
                    title: "Events",
                    value: "\(tripManager.events.count)",
                    unit: "detected",
                    icon: "exclamationmark.triangle",
                    iconColor: tripManager.events.isEmpty ? Theme.coinPositive : Theme.severityMedium
                )
            }

            HStack(spacing: 12) {
                metricCard(
                    title: "Earned",
                    value: String(format: "+%.1f", tripManager.totalCoinsEarned),
                    unit: "XCoins",
                    icon: "arrow.up.circle.fill",
                    iconColor: Theme.coinPositive
                )
                metricCard(
                    title: "Lost",
                    value: String(format: "-%.1f", tripManager.totalCoinsLost),
                    unit: "XCoins",
                    icon: "arrow.down.circle.fill",
                    iconColor: Theme.coinNegative
                )
            }
        }
    }

    private func metricCard(title: String, value: String, unit: String, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface)
                .shadow(color: Theme.cardShadow, radius: 6, y: 2)
        )
    }

    // MARK: - Category Cards

    private var categoryCardsSection: some View {
        VStack(spacing: 10) {
            Text("Category Scores")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(tripManager.categoryScores) { cat in
                    categoryCard(cat)
                }
            }
        }
    }

    private func categoryCard(_ cat: CategoryScore) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(cat.category.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                if cat.penaltyCount > 0 {
                    Text("\(cat.penaltyCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.severityMedium.cornerRadius(8))
                }
            }

            Text("\(Int(cat.score))")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Theme.scoreColor(for: cat.score))

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.surfaceLight)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.scoreColor(for: cat.score))
                        .frame(width: geo.size.width * cat.score / 100.0)
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
                .shadow(color: Theme.cardShadow, radius: 4, y: 1)
        )
    }

    // MARK: - Live Events

    private var liveEventsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Live Events")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(tripManager.events.count) total")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }

            if tripManager.events.isEmpty {
                Text("No events detected yet. Drive safely!")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.surface)
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(tripManager.events.prefix(30)) { event in
                        eventRow(event)
                        if event.id != tripManager.events.prefix(30).last?.id {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.surface)
                        .shadow(color: Theme.cardShadow, radius: 4, y: 1)
                )
            }
        }
    }

    private func eventRow(_ event: DrivingEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: event.type.icon)
                .font(.system(size: 16))
                .foregroundColor(severityColor(event.severity))
                .frame(width: 32, height: 32)
                .background(severityColor(event.severity).opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.type.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                Text(event.detail)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }

            Spacer()

            Text(event.severity.label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(severityColor(event.severity))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(severityColor(event.severity).opacity(0.1))
                .cornerRadius(6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func severityColor(_ severity: Severity) -> Color {
        switch severity {
        case .low: return Theme.severityLow
        case .medium: return Theme.severityMedium
        case .high: return Theme.severityHigh
        case .critical: return Theme.severityCritical
        }
    }

    // MARK: - Coin Animations

    private func triggerCoinAnimation(for event: CoinEvent) {
        let anim = CoinAnimation(amount: event.amount, isPositive: event.isPositive)
        coinAnimations.append(anim)

        // Remove after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            coinAnimations.removeAll { $0.id == anim.id }
        }
    }
}

// MARK: - Coin Animation Models

struct CoinAnimation: Identifiable {
    let id = UUID()
    let amount: Double
    let isPositive: Bool
}

struct CoinAnimationView: View {
    let animation: CoinAnimation

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.5

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: animation.isPositive ? "plus.circle.fill" : "minus.circle.fill")
                .font(.system(size: 14, weight: .bold))
            Text(String(format: "%.1f", abs(animation.amount)))
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .foregroundColor(animation.isPositive ? Theme.coinPositive : Theme.coinNegative)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(animation.isPositive ? Theme.coinPositive.opacity(0.15) : Theme.coinNegative.opacity(0.15))
        )
        .scaleEffect(scale)
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                offset = animation.isPositive ? -50 : 30
            }
            withAnimation(.easeOut(duration: 1.5).delay(0.5)) {
                opacity = 0
                offset = animation.isPositive ? -80 : 60
            }
        }
    }
}
