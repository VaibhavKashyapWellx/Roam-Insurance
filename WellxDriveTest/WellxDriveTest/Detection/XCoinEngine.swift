import Foundation

/// XCoin reward/penalty engine for gamified driving behavior.
/// Each trip starts with 20 XCoins. Max 30 per trip.
/// Good driving earns coins, bad events deduct coins.
final class XCoinEngine {
    private let maxCoins: Double = 30.0
    private let startingCoins: Double = 20.0

    // Earning: bonus coins for sustained safe driving
    // Award small amounts every 15 seconds if score is above thresholds
    private var cleanDrivingIntervals: Int = 0

    /// Called every 15 seconds of driving. Returns coins to award.
    func earnForCleanDriving(currentScore: Double) -> Double {
        cleanDrivingIntervals += 1

        // Only earn if maintaining a good score
        if currentScore >= 90 {
            return 1.5  // excellent driving
        } else if currentScore >= 75 {
            return 1.0  // good driving
        } else if currentScore >= 60 {
            return 0.5  // acceptable
        }
        return 0  // poor driving earns nothing
    }

    /// Returns coins to deduct for a driving event. Higher severity = more deduction.
    func deductForEvent(_ event: DrivingEvent) -> Double {
        let basePenalty: Double
        switch event.type {
        case .impact:
            basePenalty = 8.0
        case .harshBraking:
            basePenalty = 3.0
        case .rapidAcceleration:
            basePenalty = 2.0
        case .sharpTurn:
            basePenalty = 2.0
        case .swerving:
            basePenalty = 2.5
        case .extendedPhoneUse:
            basePenalty = 4.0
        case .phonePickup:
            basePenalty = 2.0
        case .phoneGlance:
            basePenalty = 1.0
        }

        // Scale by severity
        let severityMultiplier: Double
        switch event.severity {
        case .low: severityMultiplier = 0.5
        case .medium: severityMultiplier = 1.0
        case .high: severityMultiplier = 1.5
        case .critical: severityMultiplier = 2.0
        }

        return basePenalty * severityMultiplier
    }

    func reset() {
        cleanDrivingIntervals = 0
    }
}
