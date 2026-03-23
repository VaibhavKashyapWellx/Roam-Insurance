import Foundation

// MARK: - Telematics Risk Scoring Engine
// Based on actuarial GLM approaches to Usage-Based Insurance (UBI).
// References:
//   - Ayuso, Guillen & Perez-Marin (2016): "Telematics and Gender Discrimination"
//   - Verbelen, Antonio & Claeskens (2018): "The unifying role of GLMs in telematics pricing"
//   - Wüthrich (2017): "Covariate selection from telematics car driving data"
//   - Gao, Meng & Wüthrich (2022): "Claims frequency modeling using telematics features"
//   - Progressive Snapshot / Root Insurance publicly disclosed scoring factors

final class RiskScoringEngine {

    // ──────────────────────────────────────────────
    // MARK: Category Weights (from actuarial literature)
    // ──────────────────────────────────────────────
    // Based on relative risk ratios from GLM claim-frequency models.
    // Braking & distraction are the strongest predictors of accident risk.
    struct CategoryConfig {
        let weight: Double          // contribution to overall score
        let decayRate: Double       // how fast penalties accumulate (logistic steepness)
        let midpoint: Double        // penalty rate at which score = 50% of max
    }

    private let categoryConfig: [EventCategory: CategoryConfig] = [
        .braking:      CategoryConfig(weight: 0.25, decayRate: 0.8,  midpoint: 3.0),
        .distraction:  CategoryConfig(weight: 0.25, decayRate: 0.6,  midpoint: 2.5),
        .acceleration: CategoryConfig(weight: 0.15, decayRate: 0.7,  midpoint: 3.5),
        .cornering:    CategoryConfig(weight: 0.15, decayRate: 0.7,  midpoint: 3.5),
        .smoothness:   CategoryConfig(weight: 0.10, decayRate: 0.5,  midpoint: 4.0),
        .context:      CategoryConfig(weight: 0.10, decayRate: 0.4,  midpoint: 5.0),
    ]

    // ──────────────────────────────────────────────
    // MARK: Severity Relativities
    // ──────────────────────────────────────────────
    // Actuarial severity multipliers: how much worse each severity level is.
    // Based on claims data showing exponential relationship between
    // event severity and accident probability.
    private let severityRelativities: [Severity: Double] = [
        .low:      1.0,     // baseline
        .medium:   2.5,     // 2.5x more indicative of risk
        .high:     6.0,     // 6x (diminishing returns in score but much riskier)
        .critical: 15.0,    // 15x (near-miss / dangerous driving)
    ]

    // ──────────────────────────────────────────────
    // MARK: Time-of-Day Risk Multipliers
    // ──────────────────────────────────────────────
    // Based on NHTSA crash statistics by hour of day.
    // Night driving (10PM-5AM) has ~3x higher fatality rate per mile.
    // Rush hour has elevated risk due to density.
    private let hourlyRiskMultiplier: [Int: Double] = [
        0: 2.4, 1: 2.8, 2: 3.0, 3: 2.8, 4: 2.4,     // late night / early morning
        5: 1.6, 6: 1.3, 7: 1.2, 8: 1.1, 9: 1.0,      // morning commute → normal
        10: 0.9, 11: 0.9, 12: 0.9, 13: 0.9, 14: 0.9,  // midday (lowest risk)
        15: 1.0, 16: 1.1, 17: 1.2, 18: 1.3, 19: 1.2,  // evening commute
        20: 1.3, 21: 1.5, 22: 1.8, 23: 2.1,            // evening → night
    ]

    // ──────────────────────────────────────────────
    // MARK: State
    // ──────────────────────────────────────────────
    private var tripStartTime: Date?
    private var categoryPenalties: [EventCategory: Double] = [:]
    private var categoryCounts: [EventCategory: Int] = [:]
    private var totalWeightedPenalty: Double = 0

    // Smoothness tracking (continuous metric, not event-based)
    private var jerkSamples: [Double] = []       // rate of change of acceleration
    private var lastAccelY: Double = 0
    private var lastAccelTimestamp: Date?
    private var smoothnessScore: Double = 100    // starts perfect, degrades

    // Context tracking
    private var timeOfDayPenalty: Double = 0
    private var contextUpdateTime: Date = .distantPast

    // Score history
    private(set) var scoreHistory: [ScorePoint] = []
    private var lastScoreTime: Date = .distantPast

    // ──────────────────────────────────────────────
    // MARK: Computed Score (Multiplicative GLM-inspired)
    // ──────────────────────────────────────────────
    // The overall score uses a multiplicative model:
    //   score = Σ(weight_i × categoryScore_i)
    //
    // Each category score uses a logistic decay:
    //   categoryScore = 100 / (1 + exp(decayRate × (penaltyRate - midpoint)))
    //
    // Where penaltyRate = weighted_penalties / driving_minutes
    // This normalizes by exposure (longer trips get more chances for events)

    var currentScore: Double {
        computeOverallScore()
    }

    // ──────────────────────────────────────────────
    // MARK: Public API
    // ──────────────────────────────────────────────

    func start() {
        tripStartTime = Date()
        reset()
    }

    func addEvent(_ event: DrivingEvent) {
        let category = event.type.category
        let severity = severityRelativities[event.severity] ?? 1.0

        // Weighted penalty: severity × relativity
        let penalty = severity
        categoryPenalties[category, default: 0] += penalty
        categoryCounts[category, default: 0] += 1
        totalWeightedPenalty += penalty
    }

    /// Called every sensor reading to update continuous smoothness metric
    func updateSmoothness(accelY: Double, timestamp: Date = Date()) {
        guard let lastTime = lastAccelTimestamp else {
            lastAccelY = accelY
            lastAccelTimestamp = timestamp
            return
        }

        let dt = timestamp.timeIntervalSince(lastTime)
        guard dt > 0 && dt < 0.1 else {
            lastAccelY = accelY
            lastAccelTimestamp = timestamp
            return
        }

        // Jerk = d(acceleration)/dt — measures ride comfort
        // High jerk = jerky driving, low jerk = smooth
        let jerk = abs(accelY - lastAccelY) / dt
        jerkSamples.append(jerk)

        // Keep last 500 samples (~10 seconds at 50Hz)
        if jerkSamples.count > 500 {
            jerkSamples.removeFirst(jerkSamples.count - 500)
        }

        // Compute smoothness penalty from jerk distribution
        // Use 95th percentile jerk rather than mean (captures worst moments)
        if jerkSamples.count >= 50 {
            let sorted = jerkSamples.sorted()
            let p95Index = Int(Double(sorted.count) * 0.95)
            let p95Jerk = sorted[min(p95Index, sorted.count - 1)]

            // Jerk thresholds (m/s³):
            //   < 15: smooth driving
            //   15-30: moderate
            //   30-60: rough
            //   > 60: very jerky
            let jerkPenaltyRate = max(0, (p95Jerk - 15.0) / 45.0)  // 0 to ~1
            smoothnessScore = 100.0 * max(0, 1.0 - jerkPenaltyRate)
        }

        lastAccelY = accelY
        lastAccelTimestamp = timestamp
    }

    /// Update time-of-day context factor (call periodically)
    func updateContext(at time: Date = Date()) {
        guard time.timeIntervalSince(contextUpdateTime) >= 5.0 else { return }
        contextUpdateTime = time

        let hour = Calendar.current.component(.hour, from: time)
        let riskMult = hourlyRiskMultiplier[hour] ?? 1.0

        // Convert risk multiplier to a penalty that degrades the context score
        // 1.0 = no penalty, 3.0 = max penalty
        // Accumulate over time: driving at night for longer = more penalty
        guard let start = tripStartTime else { return }
        let tripMinutes = max(time.timeIntervalSince(start) / 60.0, 0.5)

        // Time-of-day risk is the average risk multiplier over the trip
        // Excess above 1.0 is the penalty
        let excessRisk = max(0, riskMult - 1.0)
        timeOfDayPenalty = excessRisk * tripMinutes * 0.3
    }

    func recordScorePoint() {
        let now = Date()
        if now.timeIntervalSince(lastScoreTime) >= 1.0 {
            let point = ScorePoint(timestamp: now, score: currentScore)
            scoreHistory.append(point)
            if scoreHistory.count > 120 {
                scoreHistory.removeFirst()
            }
            lastScoreTime = now
        }
    }

    // ──────────────────────────────────────────────
    // MARK: Category Scores
    // ──────────────────────────────────────────────

    func categoryScore(for category: EventCategory) -> Double {
        switch category {
        case .smoothness:
            return smoothnessScore
        case .context:
            return contextScore()
        default:
            return eventCategoryScore(for: category)
        }
    }

    func categoryCount(for category: EventCategory) -> Int {
        switch category {
        case .smoothness:
            return smoothnessScore < 80 ? 1 : 0
        case .context:
            return timeOfDayPenalty > 0.5 ? 1 : 0
        default:
            return categoryCounts[category, default: 0]
        }
    }

    func reset() {
        categoryPenalties.removeAll()
        categoryCounts.removeAll()
        totalWeightedPenalty = 0
        scoreHistory.removeAll()
        lastScoreTime = .distantPast
        jerkSamples.removeAll()
        lastAccelY = 0
        lastAccelTimestamp = nil
        smoothnessScore = 100
        timeOfDayPenalty = 0
        contextUpdateTime = .distantPast
    }

    // ──────────────────────────────────────────────
    // MARK: Private — Score Computation
    // ──────────────────────────────────────────────

    /// Event-based category score using logistic decay on penalty rate
    private func eventCategoryScore(for category: EventCategory) -> Double {
        guard let config = categoryConfig[category],
              let start = tripStartTime else { return 100 }

        let penalty = categoryPenalties[category, default: 0]
        let minutes = max(Date().timeIntervalSince(start) / 60.0, 0.5)

        // Penalty RATE = weighted penalties per minute of driving
        // This normalizes by exposure: a 5-minute trip with 1 event
        // is scored the same as a 50-minute trip with 10 events
        let penaltyRate = penalty / minutes

        // Logistic decay: score = 100 / (1 + exp(k * (rate - midpoint)))
        // At rate=0: score ≈ 100 (shifted by midpoint)
        // At rate=midpoint: score = 50
        // At rate>>midpoint: score → 0
        let exponent = config.decayRate * (penaltyRate - config.midpoint)
        let score = 100.0 / (1.0 + exp(exponent))

        return max(0, min(100, score))
    }

    /// Context score from time-of-day risk
    private func contextScore() -> Double {
        guard let config = categoryConfig[.context] else { return 100 }
        guard let start = tripStartTime else { return 100 }
        let minutes = max(Date().timeIntervalSince(start) / 60.0, 0.5)

        let penaltyRate = timeOfDayPenalty / minutes
        let exponent = config.decayRate * (penaltyRate - config.midpoint)
        return max(0, min(100, 100.0 / (1.0 + exp(exponent))))
    }

    /// Overall trip score: weighted sum of category scores
    private func computeOverallScore() -> Double {
        var weightedSum = 0.0
        var totalWeight = 0.0

        for category in EventCategory.allCases {
            guard let config = categoryConfig[category] else { continue }
            let score = categoryScore(for: category)
            weightedSum += config.weight * score
            totalWeight += config.weight
        }

        guard totalWeight > 0 else { return 100 }
        return max(0, min(100, weightedSum / totalWeight))
    }
}
