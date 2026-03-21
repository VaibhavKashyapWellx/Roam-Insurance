import Foundation
import CoreMotion
import Combine

final class SensorManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private let updateInterval: TimeInterval = 1.0 / 50.0  // 50 Hz

    @Published var currentReading = SensorReading()
    @Published var isActive = false

    private var onReading: ((SensorReading) -> Void)?

    init() {
        queue.name = "com.wellx.sensors"
        queue.maxConcurrentOperationCount = 1
    }

    func start(onReading: @escaping (SensorReading) -> Void) {
        self.onReading = onReading

        guard motionManager.isAccelerometerAvailable,
              motionManager.isGyroAvailable else {
            print("Sensors not available")
            return
        }

        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.gyroUpdateInterval = updateInterval

        var latestAccel: CMAccelerometerData?
        var latestGyro: CMGyroData?

        motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
            guard let data = data else { return }
            latestAccel = data
            if let gyro = latestGyro {
                self?.processSensorData(accel: data, gyro: gyro)
            }
        }

        motionManager.startGyroUpdates(to: queue) { [weak self] data, _ in
            guard let data = data else { return }
            latestGyro = data
            if let accel = latestAccel {
                self?.processSensorData(accel: accel, gyro: data)
            }
        }

        DispatchQueue.main.async { self.isActive = true }
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        onReading = nil
        DispatchQueue.main.async { self.isActive = false }
    }

    private func processSensorData(accel: CMAccelerometerData, gyro: CMGyroData) {
        let g = 9.81

        // Convert from G to m/s²
        let ax = accel.acceleration.x * g
        let ay = accel.acceleration.y * g
        let az = accel.acceleration.z * g

        let gx = gyro.rotationRate.x
        let gy = gyro.rotationRate.y
        let gz = gyro.rotationRate.z

        // Derive pitch and roll from accelerometer
        let pitch = atan2(ay, sqrt(ax * ax + az * az))
        let roll = atan2(-ax, az)

        let reading = SensorReading(
            accelX: ax,
            accelY: ay,
            accelZ: az,
            gyroX: gx,
            gyroY: gy,
            gyroZ: gz,
            pitch: pitch * 180.0 / .pi,  // Convert to degrees
            roll: roll * 180.0 / .pi,
            timestamp: Date()
        )

        onReading?(reading)

        DispatchQueue.main.async {
            self.currentReading = reading
        }
    }
}
