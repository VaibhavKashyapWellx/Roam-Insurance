import SwiftUI

struct TripSummaryView: View {
    let tripData: TripData
    let onDismiss: () -> Void
    @State private var showShareSheet = false
    @State private var jsonString: String = ""
    @State private var coinCountUp: Double = 0

    private var durationString: String {
        let total = Int(tripData.duration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d min %d sec", minutes, seconds)
    }

    private var phoneTimeString: String {
        let total = Int(tripData.totalPhoneTime)
        if total < 60 { return "\(total)s" }
        return String(format: "%dm %ds", total / 60, total % 60)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text("Trip Summary")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.top, 20)

                // Score
                ScoreRing(score: tripData.finalScore, size: 180)

                // XCoin earned card
                xCoinSummaryCard

                // Stats grid
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        summaryCard("Duration", value: durationString, icon: "clock")
                        summaryCard("Events", value: "\(tripData.events.count)", icon: "exclamationmark.triangle")
                    }
                    HStack(spacing: 12) {
                        summaryCard("Risk Level", value: tripData.riskLevel, icon: "shield.checkered",
                                    valueColor: Theme.scoreColor(for: tripData.finalScore))
                        summaryCard("Score", value: String(format: "%.0f", tripData.finalScore), icon: "gauge.with.dots.needle.33percent",
                                    valueColor: Theme.scoreColor(for: tripData.finalScore))
                    }
                }
                .padding(.horizontal, 20)

                // Phone stats
                phoneStatsSection

                // Risk factors
                if !tripData.riskFactors.isEmpty {
                    riskFactorsSection
                }

                // Category scores
                if !tripData.categoryScores.isEmpty {
                    categoryScoresSection
                }

                // Event breakdown
                if !tripData.categoryBreakdown.isEmpty {
                    eventBreakdownSection
                }

                // Event list
                if !tripData.events.isEmpty {
                    eventListSection
                }

                // Action buttons
                VStack(spacing: 10) {
                    Button(action: shareJSON) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))
                            Text("Share as JSON")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.accent, lineWidth: 1.5)
                        )
                    }

                    Button(action: onDismiss) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14))
                            Text("New Trip")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accent)
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 30)
            }
        }
        .background(Theme.background)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [jsonString])
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).delay(0.3)) {
                coinCountUp = tripData.xCoinsEarned
            }
        }
    }

    // MARK: - XCoin Summary

    private var xCoinSummaryCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.coinGold)
                Text("XCoins Earned")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", coinCountUp))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .contentTransition(.numericText())
                Text("/ 30")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.surfaceLight)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Theme.coinGold, Theme.coinPositive],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * max(0, min(1, coinCountUp / 30.0)))
                        .animation(.easeOut(duration: 1.5).delay(0.3), value: coinCountUp)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 20)

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text(String(format: "+%.1f", tripData.totalCoinsEarned))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.coinPositive)
                    Text("earned")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
                VStack(spacing: 2) {
                    Text(String(format: "-%.1f", tripData.totalCoinsLost))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.coinNegative)
                    Text("deducted")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.surface)
                .shadow(color: Theme.cardShadow, radius: 8, y: 2)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Sections

    private var phoneStatsSection: some View {
        VStack(spacing: 8) {
            sectionHeader("Phone Usage")

            HStack(spacing: 8) {
                phonePill("Pickups", value: "\(tripData.totalPhonePickups)")
                phonePill("Glances", value: "\(tripData.totalPhoneGlances)")
                phonePill("Extended", value: "\(tripData.totalExtendedUses)")
                phonePill("Time", value: phoneTimeString)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface)
                .shadow(color: Theme.cardShadow, radius: 4, y: 1)
        )
        .padding(.horizontal, 20)
    }

    private var riskFactorsSection: some View {
        VStack(spacing: 8) {
            sectionHeader("Risk Analysis")

            ForEach(tripData.riskFactors, id: \.self) { factor in
                HStack(spacing: 10) {
                    Image(systemName: factor.contains("No significant") ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(factor.contains("No significant") ? Theme.coinPositive : Theme.severityHigh)
                    Text(factor)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface)
                .shadow(color: Theme.cardShadow, radius: 4, y: 1)
        )
        .padding(.horizontal, 20)
    }

    private var categoryScoresSection: some View {
        VStack(spacing: 8) {
            sectionHeader("Category Scores")

            ForEach(tripData.categoryScores.sorted(by: { $0.value < $1.value }), id: \.key) { key, value in
                HStack {
                    Text(key)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(Int(value))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.scoreColor(for: value))
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface)
                .shadow(color: Theme.cardShadow, radius: 4, y: 1)
        )
        .padding(.horizontal, 20)
    }

    private var eventBreakdownSection: some View {
        VStack(spacing: 8) {
            sectionHeader("Event Breakdown")

            ForEach(tripData.categoryBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                HStack {
                    Text(key)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(value)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface)
                .shadow(color: Theme.cardShadow, radius: 4, y: 1)
        )
        .padding(.horizontal, 20)
    }

    private var eventListSection: some View {
        VStack(spacing: 8) {
            HStack {
                sectionHeader("All Events")
                Spacer()
                Text("\(tripData.events.count)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ForEach(tripData.events) { event in
                eventRow(event)
                if event.id != tripData.events.last?.id {
                    Divider()
                        .padding(.leading, 56)
                }
            }
            .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface)
                .shadow(color: Theme.cardShadow, radius: 4, y: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryCard(_ title: String, value: String, icon: String,
                              valueColor: Color = Theme.textPrimary) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Theme.accent)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface)
                .shadow(color: Theme.cardShadow, radius: 4, y: 1)
        )
    }

    private func phonePill(_ label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func eventRow(_ event: DrivingEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: event.type.icon)
                .font(.system(size: 14))
                .foregroundColor(severityColor(event.severity))
                .frame(width: 28, height: 28)
                .background(severityColor(event.severity).opacity(0.1))
                .cornerRadius(7)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.type.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                Text(event.detail)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }

            Spacer()

            Text(event.severity.label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(severityColor(event.severity))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(severityColor(event.severity).opacity(0.1))
                .cornerRadius(5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func severityColor(_ severity: Severity) -> Color {
        switch severity {
        case .low: return Theme.severityLow
        case .medium: return Theme.severityMedium
        case .high: return Theme.severityHigh
        case .critical: return Theme.severityCritical
        }
    }

    private func shareJSON() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(tripData),
           let str = String(data: data, encoding: .utf8) {
            jsonString = str
            showShareSheet = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
