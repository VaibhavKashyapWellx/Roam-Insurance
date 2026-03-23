import Foundation
import CoreLocation

final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var currentSpeed: Double = -1  // m/s, -1 = unavailable

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .automotiveNavigation
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        currentSpeed = -1
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // CLLocation.speed is in m/s, negative means invalid
        currentSpeed = max(location.speed, 0)
    }
}
