import Foundation
import CoreLocation

final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var currentSpeed: Double = -1  // m/s, -1 = unavailable

    /// Fires when sustained speed exceeds the auto-start threshold (20 km/h = 5.56 m/s)
    var onDrivingDetected: (() -> Void)?

    private let autoStartSpeedThreshold: Double = 5.56  // 20 km/h in m/s
    private let requiredSustainedSeconds: Int = 3
    private var consecutiveAboveCount: Int = 0
    private var hasFiredAutoStart = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .automotiveNavigation
        manager.allowsBackgroundLocationUpdates = false
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        hasFiredAutoStart = false
        consecutiveAboveCount = 0
    }

    func stop() {
        manager.stopUpdatingLocation()
        currentSpeed = -1
        consecutiveAboveCount = 0
    }

    /// Begin passive monitoring for auto-start (GPS only, no sensors)
    func startMonitoring() {
        hasFiredAutoStart = false
        consecutiveAboveCount = 0
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stopMonitoring() {
        manager.stopUpdatingLocation()
        consecutiveAboveCount = 0
    }

    func resetAutoStart() {
        hasFiredAutoStart = false
        consecutiveAboveCount = 0
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // CLLocation.speed is in m/s, negative means invalid
        currentSpeed = max(location.speed, 0)

        // Auto-start detection: require sustained speed above threshold
        if currentSpeed >= autoStartSpeedThreshold {
            consecutiveAboveCount += 1
        } else {
            consecutiveAboveCount = 0
        }

        if !hasFiredAutoStart && consecutiveAboveCount >= requiredSustainedSeconds {
            hasFiredAutoStart = true
            onDrivingDetected?()
        }
    }
}
