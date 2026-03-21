import Foundation

enum EventType: String, Codable, CaseIterable {
    case harshBraking = "Harsh Braking"
    case rapidAcceleration = "Rapid Acceleration"
    case sharpTurn = "Sharp Turn"
    case swerving = "Swerving"
    case impact = "Impact"
    case phonePickup = "Phone Pickup"
    case phoneGlance = "Phone Glance"
    case extendedPhoneUse = "Extended Phone Use"

    var icon: String {
        switch self {
        case .harshBraking: return "arrow.down.circle.fill"
        case .rapidAcceleration: return "arrow.up.circle.fill"
        case .sharpTurn: return "arrow.turn.right.up"
        case .swerving: return "arrow.left.arrow.right"
        case .impact: return "exclamationmark.triangle.fill"
        case .phonePickup: return "iphone.radiowaves.left.and.right"
        case .phoneGlance: return "eye.fill"
        case .extendedPhoneUse: return "iphone.gen3"
        }
    }

    var category: EventCategory {
        switch self {
        case .harshBraking: return .braking
        case .rapidAcceleration: return .acceleration
        case .sharpTurn: return .turns
        case .swerving: return .swerving
        case .impact: return .braking
        case .phonePickup, .phoneGlance, .extendedPhoneUse: return .phoneUse
        }
    }
}

enum EventCategory: String, Codable, CaseIterable {
    case braking = "Braking"
    case acceleration = "Acceleration"
    case turns = "Turns"
    case swerving = "Swerving"
    case phoneUse = "Phone Use"
}

enum Severity: Int, Codable, Comparable {
    case low = 1
    case medium = 2
    case high = 4
    case critical = 8

    var label: String {
        switch self {
        case .low: return "LOW"
        case .medium: return "MED"
        case .high: return "HIGH"
        case .critical: return "CRIT"
        }
    }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct DrivingEvent: Identifiable, Codable {
    let id: UUID
    let type: EventType
    let severity: Severity
    let timestamp: Date
    let value: Double
    let detail: String

    init(type: EventType, severity: Severity, timestamp: Date = Date(), value: Double = 0, detail: String = "") {
        self.id = UUID()
        self.type = type
        self.severity = severity
        self.timestamp = timestamp
        self.value = value
        self.detail = detail
    }
}

struct SensorReading {
    var accelX: Double = 0
    var accelY: Double = 0
    var accelZ: Double = 0
    var gyroX: Double = 0
    var gyroY: Double = 0
    var gyroZ: Double = 0
    var pitch: Double = 0
    var roll: Double = 0
    var timestamp: Date = Date()

    var accelMagnitude: Double {
        sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ)
    }
}

struct CategoryScore: Identifiable {
    let id = UUID()
    let category: EventCategory
    var score: Double
    var penaltyCount: Int
}

struct ScorePoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let score: Double
}

struct TripData: Codable {
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let finalScore: Double
    let riskLevel: String
    let events: [DrivingEvent]
    let totalPhonePickups: Int
    let totalPhoneGlances: Int
    let totalExtendedUses: Int
    let totalPhoneTime: TimeInterval
    let categoryBreakdown: [String: Int]
}

enum PhoneState: String {
    case resting = "RESTING"
    case pickedUp = "PICKED_UP"
    case glance = "GLANCE"
    case extendedUse = "EXTENDED_USE"
    case putDown = "PUT_DOWN"
}
