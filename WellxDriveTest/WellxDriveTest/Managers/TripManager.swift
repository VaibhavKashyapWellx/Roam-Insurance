import Foundation
import Combine

@MainActor
final class TripManager: ObservableObject {
    @Published var isTripping = false
    @Published var isMonitoring = false  // passive GPS monitoring for auto-start
    @Published var events: [DrivingEvent] = []
    @Published var currentScore: Double = 100
    @Published var currentReading = SensorReading()
    @Published var categoryScores: [CategoryScore] = []
    @Published var scoreHistory: [ScorePoint] = []
    @Published var tripDuration: TimeInterval = 0
    @Published var phoneState: PhoneState = .resting
    @Published var showSummary = false
    @Published var tripData: TripData?

    // XCoin system
    @Published var xCoins: Double = 20.0
    @Published var coinEvents: [CoinEvent] = []  // for animation
    @Published var totalCoinsEarned: Double = 0
    @Published var totalCoinsLost: Double = 0

    let sensorManager = SensorManager()
    let locationManager = LocationManager()
    private let detectionEngine = EventDetectionEngine()
    private let phoneDetector = PhoneUseDetector()
    private let scoringEngine = RiskScoringEngine()
    private let coinEngine = XCoinEngine()

    private var tripStartTime: Date?
    private var durationTimer: Timer?
    private var scoreTimer: Timer?
    private var coinTimer: Timer?

    init() {
        // Set up auto-start callback
        locationManager.onDrivingDetected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, !self.isTripping else { return }
                self.startTrip(autoDetected: true)
            }
        }
    }

    /// Begin passive GPS monitoring for auto-start
    func startMonitoring() {
        guard !isTripping && !isMonitoring else { return }
        isMonitoring = true
        locationManager.startMonitoring()
    }

    func stopMonitoring() {
        isMonitoring = false
        locationManager.stopMonitoring()
    }

    func startTrip(autoDetected: Bool = false) {
        events.removeAll()
        currentScore = 100
        scoreHistory.removeAll()
        tripDuration = 0
        showSummary = false
        tripData = nil

        // Reset XCoins
        xCoins = 20.0
        coinEvents.removeAll()
        totalCoinsEarned = 0
        totalCoinsLost = 0

        detectionEngine.reset()
        phoneDetector.reset()
        scoringEngine.start()
        coinEngine.reset()

        tripStartTime = Date()
        isTripping = true
        isMonitoring = false

        updateCategoryScores()

        if !autoDetected {
            locationManager.start()
        }
        // If auto-detected, location is already running

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

        // Coin earning timer — award coins for clean driving every 15 seconds
        coinTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isTripping else { return }
                let earned = self.coinEngine.earnForCleanDriving(currentScore: self.currentScore)
                if earned > 0 {
                    self.xCoins = min(30, self.xCoins + earned)
                    self.totalCoinsEarned += earned
                    self.addCoinEvent(amount: earned, reason: "Safe driving bonus")
                }
            }
        }
    }

    func endTrip() {
        sensorManager.stop()
        locationManager.stop()
        durationTimer?.invalidate()
        scoreTimer?.invalidate()
        coinTimer?.invalidate()
        durationTimer = nil
        scoreTimer = nil
        coinTimer = nil
        isTripping = false

        // Build trip data
        let endTime = Date()
        let duration = tripDuration

        var breakdown: [String: Int] = [:]
        for type in EventType.allCases {
            let count = events.filter { $0.type == type }.count
            if count > 0 { breakdown[type.rawValue] = count }
        }

        var catScores: [String: Double] = [:]
        for cat in EventCategory.allCases {
            catScores[cat.rawValue] = scoringEngine.categoryScore(for: cat)
        }

        var riskFactors: [String] = []
        for cat in EventCategory.allCases {
            let score = scoringEngine.categoryScore(for: cat)
            if score < 70 {
                let severity = score < 40 ? "Critical" : (score < 55 ? "High" : "Elevated")
                riskFactors.append("\(severity) \(cat.rawValue.lowercased()) risk (score: \(Int(score)))")
            }
        }
        if riskFactors.isEmpty { riskFactors.append("No significant risk factors detected") }

        // Finalize coins — clamp to [0, 30]
        xCoins = max(0, min(30, xCoins))

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
            categoryBreakdown: breakdown,
            categoryScores: catScores,
            riskFactors: riskFactors,
            xCoinsEarned: xCoins,
            totalCoinsEarned: totalCoinsEarned,
            totalCoinsLost: totalCoinsLost
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
            // Deduct coins for bad events
            let deduction = coinEngine.deductForEvent(event)
            if deduction > 0 {
                xCoins = max(0, xCoins - deduction)
                totalCoinsLost += deduction
                addCoinEvent(amount: -deduction, reason: event.type.rawValue)
            }
        }

        // Phone use detection
        let phoneEvents = phoneDetector.processReading(reading)
        for event in phoneEvents {
            events.insert(event, at: 0)
            scoringEngine.addEvent(event)
            let deduction = coinEngine.deductForEvent(event)
            if deduction > 0 {
                xCoins = max(0, xCoins - deduction)
                totalCoinsLost += deduction
                addCoinEvent(amount: -deduction, reason: event.type.rawValue)
            }
        }
        phoneState = phoneDetector.state

        scoringEngine.updateSmoothness(accelY: reading.accelY, timestamp: reading.timestamp)
        scoringEngine.updateContext(at: reading.timestamp)

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

    private func addCoinEvent(amount: Double, reason: String) {
        let event = CoinEvent(amount: amount, reason: reason)
        coinEvents.insert(event, at: 0)
        // Keep only recent events for animation
        if coinEvents.count > 20 {
            coinEvents = Array(coinEvents.prefix(20))
        }
    }
}
