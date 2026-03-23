import Foundation
import Combine

@MainActor
final class TripManager: ObservableObject {
    @Published var isTripping = false
    @Published var events: [DrivingEvent] = []
    @Published var currentScore: Double = 100
    @Published var currentReading = SensorReading()
    @Published var categoryScores: [CategoryScore] = []
    @Published var scoreHistory: [ScorePoint] = []
    @Published var tripDuration: TimeInterval = 0
    @Published var phoneState: PhoneState = .resting
    @Published var showSummary = false
    @Published var tripData: TripData?

    let sensorManager = SensorManager()
    private let locationManager = LocationManager()
    private let detectionEngine = EventDetectionEngine()
    private let phoneDetector = PhoneUseDetector()
    private let scoringEngine = RiskScoringEngine()

    private var tripStartTime: Date?
    private var durationTimer: Timer?
    private var scoreTimer: Timer?

    func startTrip() {
        events.removeAll()
        currentScore = 100
        scoreHistory.removeAll()
        tripDuration = 0
        showSummary = false
        tripData = nil

        detectionEngine.reset()
        phoneDetector.reset()
        scoringEngine.start()

        tripStartTime = Date()
        isTripping = true

        updateCategoryScores()
        locationManager.start()

        sensorManager.start { [weak self] reading in
            Task { @MainActor [weak self] in
                self?.processSensorReading(reading)
            }
        }

        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.tripStartTime else { return }
                self.tripDuration = Date().timeIntervalSince(start)
            }
        }

        scoreTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.scoringEngine.recordScorePoint()
                self.currentScore = self.scoringEngine.currentScore
                self.scoreHistory = self.scoringEngine.scoreHistory
                self.updateCategoryScores()
            }
        }
    }

    func endTrip() {
        sensorManager.stop()
        locationManager.stop()
        durationTimer?.invalidate()
        scoreTimer?.invalidate()
        durationTimer = nil
        scoreTimer = nil
        isTripping = false

        // Build trip data
        let endTime = Date()
        let duration = tripDuration

        var breakdown: [String: Int] = [:]
        for type in EventType.allCases {
            let count = events.filter { $0.type == type }.count
            if count > 0 { breakdown[type.rawValue] = count }
        }

        tripData = TripData(
            startTime: tripStartTime ?? endTime,
            endTime: endTime,
            duration: duration,
            finalScore: currentScore,
            riskLevel: Theme.riskLabel(for: currentScore),
            events: events,
            totalPhonePickups: phoneDetector.pickupCount,
            totalPhoneGlances: phoneDetector.glanceCount,
            totalExtendedUses: phoneDetector.extendedUseCount,
            totalPhoneTime: phoneDetector.totalPhoneTime,
            categoryBreakdown: breakdown
        )

        showSummary = true
    }

    func exportJSON() -> String? {
        guard let data = tripData else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let jsonData = try? encoder.encode(data) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }

    // MARK: - Private

    private func processSensorReading(_ reading: SensorReading) {
        var reading = reading
        reading.speed = locationManager.currentSpeed
        currentReading = reading

        // Driving event detection
        let drivingEvents = detectionEngine.processSensorReading(reading)
        for event in drivingEvents {
            events.insert(event, at: 0)
            scoringEngine.addEvent(event)
        }

        // Phone use detection
        let phoneEvents = phoneDetector.processReading(reading)
        for event in phoneEvents {
            events.insert(event, at: 0)
            scoringEngine.addEvent(event)
        }
        phoneState = phoneDetector.state

        // Smoothness tracking
        scoringEngine.updateSmoothness(accelY: reading.accelY)

        // Cap events list
        if events.count > 500 {
            events = Array(events.prefix(500))
        }
    }

    private func updateCategoryScores() {
        categoryScores = EventCategory.allCases.map { cat in
            CategoryScore(
                category: cat,
                score: scoringEngine.categoryScore(for: cat),
                penaltyCount: scoringEngine.categoryCount(for: cat)
            )
        }
    }
}
