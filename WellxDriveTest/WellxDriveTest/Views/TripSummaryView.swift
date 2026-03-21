import SwiftUI

struct TripSummaryView: View {
    let tripData: TripData
    let onDismiss: () -> Void
    @State private var showShareSheet = false
    @State private var jsonString: String = ""

    private var durationString: String {
        let total = Int(tripData.duration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d min %d sec", minutes, seconds)
    }

    private var phoneTimeString: String {
        let total = Int(tripData.totalPhoneTime)
        if total < 60 {
            return "\(total)s"
        }
        return String(format: "%dm %ds", total / 60, total % 60)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                Text("TRIP SUMMARY")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textTertiary)
                    .tracking(2)
                    .padding(.top, 16)

                // Score
                ScoreRing(score: tripData.finalScore, size: 160)

                // Stats grid
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        statCard("Duration", value: durationString, icon: "clock")
                        statCard("Events", value: "\(tripData.events.count)", icon: "exclamationmark.triangle")
                    }

                    HStack(spacing: 12) {
                        statCard("Risk Level", value: tripData.riskLevel, icon: "shield",
                                 valueColor: Theme.scoreColor(for: tripData.finalScore))
                        statCard("Score", value: String(format: "%.0f", tripData.finalScore), icon: "gauge",
                                 valueColor: Theme.scoreColor(for: tripData.finalScore))
                    }
                }
                .padding(.horizontal, 16)

                // Phone stats
                VStack(spacing: 8) {
                    Text("PHONE USAGE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                        .tracking(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        phoneStatPill("Pickups", count: tripData.totalPhonePickups)
                        phoneStatPill("Glances", count: tripData.totalPhoneGlances)
                        phoneStatPill("Extended", count: tripData.totalExtendedUses)
                        phoneStatPill("Time", text: phoneTimeString)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.surface)
                .cornerRadius(10)
                .padding(.horizontal, 12)

                // Event breakdown
                if !tripData.categoryBreakdown.isEmpty {
                    VStack(spacing: 6) {
                        Text("EVENT BREAKDOWN")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Theme.textTertiary)
                            .tracking(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(tripData.categoryBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                            HStack {
                                Text(key)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("\(value)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.surface)
                    .cornerRadius(10)
                    .padding(.horizontal, 12)
                }

                // Event list
                if !tripData.events.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Text("ALL EVENTS")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Theme.textTertiary)
                                .tracking(1)
                            Spacer()
                            Text("\(tripData.events.count)")
                                .font(Theme.monoSmall)
                                .foregroundColor(Theme.textTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                        ForEach(tripData.events) { event in
                            EventRow(event: event)
                            Divider()
                                .background(Theme.surfaceLight)
                        }
                    }
                    .background(Theme.surface)
                    .cornerRadius(10)
                    .padding(.horizontal, 12)
                }

                // Share button
                Button(action: shareJSON) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        Text("SHARE AS JSON")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent.opacity(0.15))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 16)

                // New trip button
                Button(action: onDismiss) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14))
                        Text("NEW TRIP")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundColor(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 30)
            }
        }
        .background(Theme.background)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [jsonString])
        }
    }

    private func statCard(_ title: String, value: String, icon: String,
                           valueColor: Color = Theme.textPrimary) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.accent)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surface)
        .cornerRadius(10)
    }

    private func phoneStatPill(_ label: String, count: Int? = nil, text: String? = nil) -> some View {
        VStack(spacing: 2) {
            Text(count.map { "\($0)" } ?? text ?? "0")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
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
