import Foundation

final class EventDetectionEngine {
    // Thresholds
    private let harshBrakingThreshold: Double = 4.5   // m/s²
    private let rapidAccelThreshold: Double = 3.5     // m/s²
    private let sharpTurnThreshold: Double = 1.2      // rad/s
    private let impactThreshold: Double = 15.0        // m/s²
    private let cooldownInterval: TimeInterval = 2.0  // seconds

    // Rolling buffers for smoothing (50 samples = 1 second at 50Hz)
    private var accelYBuffer = RollingBuffer<Double>(capacity: 25, defaultValue: 0)
    private var gyroZBuffer = RollingBuffer<Double>(capacity: 25, defaultValue: 0)
    private var accelMagBuffer = RollingBuffer<Double>(capacity: 10, defaultValue: 0)

    // Swerving detection: gyroZ variance over time
    private var gyroZVarianceBuffer = RollingBuffer<Double>(capacity: 50, defaultValue: 0)
    private var gyroZShortBuffer = RollingBuffer<Double>(capacity: 10, defaultValue: 0)

    // Cooldowns
    private var lastEventTime: [EventType: Date] = [:]

    // Smoothed values
    private(set) var smoothedAccelY: Double = 0
    private(set) var smoothedGyroZ: Double = 0

    func processSensorReading(_ reading: SensorReading) -> [DrivingEvent] {
        var events: [DrivingEvent] = []

        // Update buffers
        accelYBuffer.append(reading.accelY)
        gyroZBuffer.append(reading.gyroZ)
        accelMagBuffer.append(reading.accelMagnitude)

        // Short buffer for swerve variance
        gyroZShortBuffer.append(reading.gyroZ)
        if gyroZShortBuffer.isFull {
            gyroZVarianceBuffer.append(gyroZShortBuffer.variance)
        }

        // Smoothed values (use buffer means)
        smoothedAccelY = accelYBuffer.mean
        smoothedGyroZ = gyroZBuffer.mean

        let now = reading.timestamp

        // 1. Impact detection (highest priority, raw magnitude)
        if reading.accelMagnitude > impactThreshold {
            if let event = createEventIfCooldown(.impact, severity: .critical, value: reading.accelMagnitude,
                                                  detail: String(format: "%.1f m/s²", reading.accelMagnitude), at: now) {
                events.append(event)
            }
        }

        // 2. Harsh braking (negative Y-axis deceleration)
        // When braking, the phone's Y-axis shows negative acceleration (deceleration)
        let brakingForce = -smoothedAccelY  // Negate: deceleration is negative accelY
        if brakingForce > harshBrakingThreshold {
            let severity = classifyBrakingSeverity(brakingForce)
            if let event = createEventIfCooldown(.harshBraking, severity: severity, value: brakingForce,
                                                  detail: String(format: "%.1f m/s²", brakingForce), at: now) {
                events.append(event)
            }
        }

        // 3. Rapid acceleration (positive Y-axis)
        if smoothedAccelY > rapidAccelThreshold {
            let severity = classifyAccelSeverity(smoothedAccelY)
            if let event = createEventIfCooldown(.rapidAcceleration, severity: severity, value: smoothedAccelY,
                                                  detail: String(format: "%.1f m/s²", smoothedAccelY), at: now) {
                events.append(event)
            }
        }

        // 4. Sharp turns (gyroscope Z-axis yaw rate)
        let absGyroZ = abs(reading.gyroZ)
        if absGyroZ > sharpTurnThreshold {
            let severity = classifyTurnSeverity(absGyroZ)
            let direction = reading.gyroZ > 0 ? "Left" : "Right"
            if let event = createEventIfCooldown(.sharpTurn, severity: severity, value: absGyroZ,
                                                  detail: String(format: "%@ %.2f rad/s", direction, absGyroZ), at: now) {
                events.append(event)
            }
        }

        // 5. Swerving (rapid gyro Z variance oscillation)
        if gyroZVarianceBuffer.count >= 20 {
            let varianceOfVariance = computeVarianceOfVariance()
            if varianceOfVariance > 0.3 {
                let severity: Severity = varianceOfVariance > 1.0 ? .high : (varianceOfVariance > 0.6 ? .medium : .low)
                if let event = createEventIfCooldown(.swerving, severity: severity, value: varianceOfVariance,
                                                      detail: String(format: "Var: %.2f", varianceOfVariance), at: now) {
                    events.append(event)
                }
            }
        }

        return events
    }

    func reset() {
        accelYBuffer = RollingBuffer(capacity: 25, defaultValue: 0)
        gyroZBuffer = RollingBuffer(capacity: 25, defaultValue: 0)
        accelMagBuffer = RollingBuffer(capacity: 10, defaultValue: 0)
        gyroZVarianceBuffer = RollingBuffer(capacity: 50, defaultValue: 0)
        gyroZShortBuffer = RollingBuffer(capacity: 10, defaultValue: 0)
        lastEventTime.removeAll()
        smoothedAccelY = 0
        smoothedGyroZ = 0
    }

    // MARK: - Private

    private func createEventIfCooldown(_ type: EventType, severity: Severity, value: Double,
                                        detail: String, at time: Date) -> DrivingEvent? {
        if let lastTime = lastEventTime[type],
           time.timeIntervalSince(lastTime) < cooldownInterval {
            return nil
        }
        lastEventTime[type] = time
        return DrivingEvent(type: type, severity: severity, timestamp: time, value: value, detail: detail)
    }

    private func classifyBrakingSeverity(_ force: Double) -> Severity {
        if force > 9.0 { return .critical }
        if force > 7.0 { return .high }
        if force > 5.5 { return .medium }
        return .low
    }

    private func classifyAccelSeverity(_ force: Double) -> Severity {
        if force > 7.0 { return .critical }
        if force > 5.5 { return .high }
        if force > 4.5 { return .medium }
        return .low
    }

    private func classifyTurnSeverity(_ rate: Double) -> Severity {
        if rate > 3.0 { return .critical }
        if rate > 2.0 { return .high }
        if rate > 1.5 { return .medium }
        return .low
    }

    private func computeVarianceOfVariance() -> Double {
        let vals = gyroZVarianceBuffer.values
        guard vals.count > 1 else { return 0 }
        let mean = vals.reduce(0, +) / Double(vals.count)
        let variance = vals.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(vals.count - 1)
        return variance
    }
}
