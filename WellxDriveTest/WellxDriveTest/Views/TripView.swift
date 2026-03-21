import SwiftUI

struct TripView: View {
    @ObservedObject var tripManager: TripManager

    private var durationString: String {
        let total = Int(tripManager.tripDuration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WellxDrive")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Theme.accent)
                        Text("Driving Behavior Test")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textTertiary)
                    }
                    Spacer()
                    if tripManager.isTripping {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(durationString)
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.textPrimary)
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Theme.severityCritical)
                                    .frame(width: 6, height: 6)
                                Text("RECORDING")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Theme.severityCritical)
                                    .tracking(1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Score Ring
                ScoreRing(score: tripManager.currentScore, size: tripManager.isTripping ? 160 : 180)
                    .padding(.vertical, tripManager.isTripping ? 4 : 16)

                // Start/End Button
                Button(action: {
                    if tripManager.isTripping {
                        tripManager.endTrip()
                    } else {
                        tripManager.startTrip()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: tripManager.isTripping ? "stop.fill" : "play.fill")
                            .font(.system(size: 14))
                        Text(tripManager.isTripping ? "END TRIP" : "START TRIP")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(1.5)
                    }
                    .foregroundColor(tripManager.isTripping ? Theme.background : Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        tripManager.isTripping
                            ? Theme.severityCritical
                            : Theme.accent
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)

                if tripManager.isTripping {
                    // Sensor readings
                    SensorReadingsView(reading: tripManager.currentReading, phoneState: tripManager.phoneState)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.surface)
                        .cornerRadius(10)
                        .padding(.horizontal, 12)

                    // Category scores
                    VStack(spacing: 4) {
                        Text("CATEGORY SCORES")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Theme.textTertiary)
                            .tracking(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(tripManager.categoryScores) { cat in
                            CategoryScoreBar(
                                category: cat.category,
                                score: cat.score,
                                count: cat.penaltyCount
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.surface)
                    .cornerRadius(10)
                    .padding(.horizontal, 12)

                    // Score trend
                    ScoreTrendChart(points: tripManager.scoreHistory)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.surface)
                        .cornerRadius(10)
                        .padding(.horizontal, 12)

                    // Events feed
                    VStack(spacing: 0) {
                        HStack {
                            Text("LIVE EVENTS")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Theme.textTertiary)
                                .tracking(1)
                            Spacer()
                            Text("\(tripManager.events.count) total")
                                .font(Theme.monoSmall)
                                .foregroundColor(Theme.textTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                        if tripManager.events.isEmpty {
                            Text("No events detected yet. Start driving!")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textTertiary)
                                .padding(.vertical, 20)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(tripManager.events.prefix(50)) { event in
                                    EventRow(event: event)
                                    Divider()
                                        .background(Theme.surfaceLight)
                                }
                            }
                        }
                    }
                    .background(Theme.surface)
                    .cornerRadius(10)
                    .padding(.horizontal, 12)
                } else if !tripManager.isTripping && tripManager.events.isEmpty {
                    // Idle state
                    VStack(spacing: 8) {
                        Text("Mount your phone in your car and tap Start Trip")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)

                        VStack(alignment: .leading, spacing: 4) {
                            featureRow("Harsh braking & rapid acceleration")
                            featureRow("Sharp turns & swerving")
                            featureRow("Impact detection")
                            featureRow("Phone pickup, glance & extended use")
                            featureRow("Real-time risk scoring")
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }

                Spacer(minLength: 20)
            }
        }
        .background(Theme.background)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(Theme.accent)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
