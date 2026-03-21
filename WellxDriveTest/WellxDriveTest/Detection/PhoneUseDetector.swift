import Foundation

final class PhoneUseDetector {
    // State machine
    private(set) var state: PhoneState = .resting
    private var stateEntryTime: Date = Date()

    // Baseline calibration
    private var baselinePitch: Double = 0
    private var baselineRoll: Double = 0
    private var isCalibrated = false
    private var calibrationSamples: [(pitch: Double, roll: Double)] = []
    private let calibrationCount = 100  // ~2 seconds at 50Hz

    // Buffers for multi-signal fusion
    private var gyroMagnitudeBuffer = RollingBuffer<Double>(capacity: 25, defaultValue: 0)
    private var accelVarianceBuffer = RollingBuffer<Double>(capacity: 25, defaultValue: 0)
    private var accelMagBuffer = RollingBuffer<Double>(capacity: 10, defaultValue: 0)

    // Phone use tracking
    private(set) var pickupCount = 0
    private(set) var glanceCount = 0
    private(set) var extendedUseCount = 0
    private(set) var totalPhoneTime: TimeInterval = 0
    private var currentPickupStart: Date?

    // Cooldown
    private var lastPhoneEventTime: Date = .distantPast
    private let cooldownInterval: TimeInterval = 2.0

    // Thresholds
    private let pitchDeltaThreshold: Double = 25.0  // degrees
    private let rollDeltaThreshold: Double = 30.0   // degrees
    private let gyroTremorMin: Double = 0.15        // rad/s
    private let gyroTremorMax: Double = 1.5         // rad/s
    private let fusionConfidenceThreshold: Double = 0.6
    private let glanceMinDuration: TimeInterval = 0.5
    private let glanceMaxDuration: TimeInterval = 3.0
    private let extendedUseThreshold: TimeInterval = 5.0

    func processReading(_ reading: SensorReading) -> [DrivingEvent] {
        // Calibration phase
        if !isCalibrated {
            calibrationSamples.append((pitch: reading.pitch, roll: reading.roll))
            if calibrationSamples.count >= calibrationCount {
                baselinePitch = calibrationSamples.map(\.pitch).reduce(0, +) / Double(calibrationSamples.count)
                baselineRoll = calibrationSamples.map(\.roll).reduce(0, +) / Double(calibrationSamples.count)
                isCalibrated = true
                calibrationSamples = []
            }
            return []
        }

        // Update buffers
        let gyroMag = sqrt(reading.gyroX * reading.gyroX + reading.gyroY * reading.gyroY + reading.gyroZ * reading.gyroZ)
        gyroMagnitudeBuffer.append(gyroMag)
        accelMagBuffer.append(reading.accelMagnitude)
        if accelMagBuffer.isFull {
            accelVarianceBuffer.append(accelMagBuffer.variance)
        }

        // Compute fusion signals
        let confidence = computePickupConfidence(reading)
        let now = reading.timestamp

        var events: [DrivingEvent] = []

        switch state {
        case .resting:
            if confidence >= fusionConfidenceThreshold {
                transitionTo(.pickedUp, at: now)
                currentPickupStart = now
            }

        case .pickedUp:
            let holdDuration = now.timeIntervalSince(stateEntryTime)

            if confidence < fusionConfidenceThreshold * 0.6 {
                // Phone put back down
                if holdDuration >= glanceMinDuration && holdDuration <= glanceMaxDuration {
                    // It was a glance
                    transitionTo(.glance, at: now)
                    glanceCount += 1
                    totalPhoneTime += holdDuration
                    if let event = createPhoneEvent(.phoneGlance, severity: .medium,
                                                     detail: String(format: "Glance: %.1fs", holdDuration), at: now) {
                        events.append(event)
                    }
                    transitionTo(.putDown, at: now)
                } else if holdDuration < glanceMinDuration {
                    // Too brief, ignore — likely sensor noise
                    transitionTo(.putDown, at: now)
                } else {
                    // Was extended, generate event below
                    totalPhoneTime += holdDuration
                    transitionTo(.putDown, at: now)
                }
            } else if holdDuration > extendedUseThreshold {
                transitionTo(.extendedUse, at: now)
                pickupCount += 1
                if let event = createPhoneEvent(.phonePickup, severity: .low,
                                                 detail: "Phone picked up", at: now) {
                    events.append(event)
                }
            }

        case .extendedUse:
            let totalDuration = now.timeIntervalSince(currentPickupStart ?? stateEntryTime)

            if confidence < fusionConfidenceThreshold * 0.6 {
                // Phone put down after extended use
                extendedUseCount += 1
                totalPhoneTime += totalDuration
                let severity = classifyExtendedUseSeverity(totalDuration)
                if let event = createPhoneEvent(.extendedPhoneUse, severity: severity,
                                                 detail: String(format: "%.0fs phone use", totalDuration), at: now) {
                    events.append(event)
                }
                transitionTo(.putDown, at: now)
            }

        case .glance:
            // Transient state, immediately goes to putDown
            transitionTo(.putDown, at: now)

        case .putDown:
            // Brief transition state, go back to resting
            transitionTo(.resting, at: now)
        }

        return events
    }

    func reset() {
        state = .resting
        stateEntryTime = Date()
        isCalibrated = false
        calibrationSamples = []
        gyroMagnitudeBuffer = RollingBuffer(capacity: 25, defaultValue: 0)
        accelVarianceBuffer = RollingBuffer(capacity: 25, defaultValue: 0)
        accelMagBuffer = RollingBuffer(capacity: 10, defaultValue: 0)
        pickupCount = 0
        glanceCount = 0
        extendedUseCount = 0
        totalPhoneTime = 0
        currentPickupStart = nil
        lastPhoneEventTime = .distantPast
    }

    // MARK: - Multi-signal Fusion

    private func computePickupConfidence(_ reading: SensorReading) -> Double {
        var signals: [Double] = []

        // Signal 1: Orientation change from baseline
        let pitchDelta = abs(reading.pitch - baselinePitch)
        let rollDelta = abs(reading.roll - baselineRoll)
        let orientationSignal = Swift.min(1.0, Swift.max(pitchDelta / pitchDeltaThreshold, rollDelta / rollDeltaThreshold))
        signals.append(orientationSignal)

        // Signal 2: Gyro micro-motion (hand tremor pattern)
        if gyroMagnitudeBuffer.count >= 10 {
            let avgGyro = gyroMagnitudeBuffer.mean
            let gyroVar = gyroMagnitudeBuffer.variance
            // Hand tremor: consistent small movements with low variance
            let inTremorRange = avgGyro >= gyroTremorMin && avgGyro <= gyroTremorMax
            let lowVariance = gyroVar < 0.5
            let tremorSignal: Double = (inTremorRange && lowVariance) ? Swift.min(1.0, avgGyro / 0.5) : 0
            signals.append(tremorSignal)
        } else {
            signals.append(0)
        }

        // Signal 3: Accelerometer decoupling (variance change)
        if accelVarianceBuffer.count >= 5 {
            let recentVariance = accelVarianceBuffer.mean
            // Higher variance when phone is in hand vs mounted
            let decouplingSignal = Swift.min(1.0, recentVariance / 2.0)
            signals.append(decouplingSignal)
        } else {
            signals.append(0)
        }

        // Weighted fusion: orientation is strongest signal
        let weights = [0.5, 0.3, 0.2]
        var confidence = 0.0
        for i in 0..<signals.count {
            confidence += signals[i] * weights[i]
        }

        return confidence
    }

    private func transitionTo(_ newState: PhoneState, at time: Date) {
        state = newState
        stateEntryTime = time
    }

    private func createPhoneEvent(_ type: EventType, severity: Severity, detail: String, at time: Date) -> DrivingEvent? {
        if time.timeIntervalSince(lastPhoneEventTime) < cooldownInterval {
            return nil
        }
        lastPhoneEventTime = time
        return DrivingEvent(type: type, severity: severity, timestamp: time, detail: detail)
    }

    private func classifyExtendedUseSeverity(_ duration: TimeInterval) -> Severity {
        if duration > 30 { return .critical }
        if duration > 15 { return .high }
        if duration > 10 { return .medium }
        return .low
    }
}
