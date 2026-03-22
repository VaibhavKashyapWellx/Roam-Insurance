import Foundation

final class RiskScoringEngine {
    // Category weights
    private let weights: [EventCategory: Double] = [
        .phoneUse: 0.40,
        .braking: 0.20,
        .acceleration: 0.12,
        .turns: 0.12,
        .swerving: 0.08,
    ]
    private let smoothnessWeight: Double = 0.08

    // Penalty tracking per category
    private var categoryPenalties: [EventCategory: Double] = [:]
    private var categoryCounts: [EventCategory: Int] = [:]

    // Overall
    private var totalPenalty: Double = 0
    private var tripStartTime: Date?

    // Score history
    private(set) var scoreHistory: [ScorePoint] = []
    private var lastScoreTime: Date = .distantPast

    // Smoothness tracking
    private var accelJerkBuffer = RollingBuffer<Double>(capacity: 50, defaultValue: 0)
    private var lastAccelY: Double = 0
    private var smoothnessPenalty: Double = 0

    var currentScore: Double {
        computeScore()
    }

    func addEvent(_ event: DrivingEvent) {
        let penalty = Double(event.severity.rawValue)
        let category = event.type.category

        categoryPenalties[category, default: 0] += penalty
        categoryCounts[category, default: 0] += 1
        totalPenalty += penalty
    }

    func updateSmoothness(accelY: Double) {
        let jerk = abs(accelY - lastAccelY)
        lastAccelY = accelY
        accelJerkBuffer.append(jerk)

        if accelJerkBuffer.isFull {
            let avgJerk = accelJerkBuffer.mean
            // Penalize high average jerk (threshold raised for gravity-free data)
            if avgJerk > 5.0 {
                smoothnessPenalty += 0.005
            }
        }
    }

    func recordScorePoint() {
        let now = Date()
        if now.timeIntervalSince(lastScoreTime) >= 1.0 {
            let point = ScorePoint(timestamp: now, score: currentScore)
            scoreHistory.append(point)
            // Keep last 60 points
            if scoreHistory.count > 60 {
                scoreHistory.removeFirst()
            }
            lastScoreTime = now
        }
    }

    func categoryScore(for category: EventCategory) -> Double {
        let penalty = categoryPenalties[category, default: 0]
        guard let start = tripStartTime else { return 100 }
        let minutes = max(Date().timeIntervalSince(start) / 60.0, 0.5)
        let normalizedPenalty = penalty / minutes
        return 100.0 / (1.0 + exp(0.3 * normalizedPenalty - 1.0))
    }

    func categoryCount(for category: EventCategory) -> Int {
        categoryCounts[category, default: 0]
    }

    func start() {
        tripStartTime = Date()
        reset()
    }

    func reset() {
        categoryPenalties.removeAll()
        categoryCounts.removeAll()
        totalPenalty = 0
        scoreHistory.removeAll()
        lastScoreTime = .distantPast
        accelJerkBuffer = RollingBuffer(capacity: 50, defaultValue: 0)
        lastAccelY = 0
        smoothnessPenalty = 0
    }

    // MARK: - Private

    private func computeScore() -> Double {
        guard let start = tripStartTime else { return 100 }
        let minutes = max(Date().timeIntervalSince(start) / 60.0, 0.5)

        // Normalize penalties by trip duration
        let normalizedPenalty = (totalPenalty + smoothnessPenalty) / minutes

        // Logistic curve: score = 100 / (1 + exp(0.15 * totalPenalty - 2))
        let score = 100.0 / (1.0 + exp(0.15 * normalizedPenalty - 2.0))
        return max(0, min(100, score))
    }
}
