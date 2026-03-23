import Foundation

final class EventDetectionEngine {
    // Thresholds (tuned for gravity-free userAcceleration from CMDeviceMotion)
    private let harshBrakingThreshold: Double = 8.0   // m/s² (~0.8g, genuine hard braking)
    private let rapidAccelThreshold: Double = 6.5     // m/s² (~0.66g, aggressive acceleration)
    private let sharpTurnThreshold: Double = 2.5      // rad/s (genuine sharp turn)
    private let impactThreshold: Double = 20.0        // m/s² (~2g, real collision force)
    private let cooldownInterval: TimeInterval = 3.0  // seconds
    private let warmupDuration: TimeInterval = 5.0    // ignore events for first 5 seconds
    private let minEstimatedSpeed: Double = 3.5       // m/s (~12 km/h) - need real sustained driving

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

    // Movement estimation (no GPS needed)
    private var tripStartTime: Date?
    private var estimatedSpeed: Double = 0        // rough m/s from integrating accelY
    private var lastReadingTime: Date?
    private let speedDecay: Double = 0.95         // aggressive decay — brief hand movements fade fast
    private let accelNoiseFloor: Double = 1.5     // m/s² — ignore small accelerations (hand bumps, tilts)

    func processSensorReading(_ reading: SensorReading) -> [DrivingEvent] {
        var events: [DrivingEvent] = []

        // Track trip start for warmup
        if tripStartTime == nil { tripStartTime = reading.timestamp }

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

        // Estimate speed from accelerometer integration (rough but filters stationary false positives)
        if let lastTime = lastReadingTime {
            let dt = reading.timestamp.timeIntervalSince(lastTime)
            if dt > 0 && dt < 0.1 {  // sanity check on dt
                // Only integrate meaningful sustained acceleration (hand movements stay below this)
                let accelForIntegration = abs(smoothedAccelY) > accelNoiseFloor ? smoothedAccelY : 0
                estimatedSpeed += accelForIntegration * dt
                estimatedSpeed *= speedDecay  // decay to prevent unbounded drift
                if estimatedSpeed < 0 { estimatedSpeed = 0 }  // speed can't be negative
            }
        }
        lastReadingTime = reading.timestamp

        let now = reading.timestamp
        let inWarmup = now.timeIntervalSince(tripStartTime ?? now) < warmupDuration

        // Use GPS speed if available, otherwise fall back to estimated speed
        let isMoving: Bool
        if reading.speed >= 0 {
            isMoving = reading.speed >= 1.4  // GPS available: use 5 km/h threshold
        } else {
            isMoving = estimatedSpeed >= minEstimatedSpeed  // No GPS: use accel-based estimate
        }

        // 1. Impact detection (highest priority, raw magnitude — always active regardless of speed)
        if reading.accelMagnitude > impactThreshold {
            if let event = createEventIfCooldown(.impact, severity: .critical, value: reading.accelMagnitude,
                                                  detail: String(format: "%.1f m/s²", reading.accelMagnitude), at: now) {
                events.append(event)
            }
        }

        // Skip driving behavior events during warmup or when stationary
        guard !inWarmup && isMoving else { return events }

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

        // 4. Sharp turns (gyroscope Z-axis yaw rate, use smoothed value to filter noise)
        let absGyroZ = abs(smoothedGyroZ)
        if absGyroZ > sharpTurnThreshold {
            let severity = classifyTurnSeverity(absGyroZ)
            let direction = smoothedGyroZ > 0 ? "Left" : "Right"
            if let event = createEventIfCooldown(.sharpTurn, severity: severity, value: absGyroZ,
                                                  detail: String(format: "%@ %.2f rad/s", direction, absGyroZ), at: now) {
                events.append(event)
            }
        }

        // 5. Swerving (rapid gyro Z variance oscillation)
        if gyroZVarianceBuffer.count >= 20 {
            let varianceOfVariance = computeVarianceOfVariance()
            if varianceOfVariance > 0.8 {
                let severity: Severity = varianceOfVariance > 2.0 ? .high : (varianceOfVariance > 1.2 ? .medium : .low)
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
        tripStartTime = nil
        estimatedSpeed = 0
        lastReadingTime = nil
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
        if force > 14.0 { return .critical }
        if force > 11.0 { return .high }
        if force > 9.0 { return .medium }
        return .low
    }

    private func classifyAccelSeverity(_ force: Double) -> Severity {
        if force > 12.0 { return .critical }
        if force > 9.0 { return .high }
        if force > 7.0 { return .medium }
        return .low
    }

    private func classifyTurnSeverity(_ rate: Double) -> Severity {
        if rate > 5.0 { return .critical }
        if rate > 3.5 { return .high }
        if rate > 2.5 { return .medium }
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
