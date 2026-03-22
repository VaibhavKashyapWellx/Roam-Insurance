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

        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }

        motionManager.deviceMotionUpdateInterval = updateInterval

        // Use CMDeviceMotion which provides gravity-free userAcceleration
        // and attitude-corrected rotation rate via sensor fusion
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let motion = motion else { return }
            self?.processDeviceMotion(motion)
        }

        DispatchQueue.main.async { self.isActive = true }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        onReading = nil
        DispatchQueue.main.async { self.isActive = false }
    }

    private func processDeviceMotion(_ motion: CMDeviceMotion) {
        let g = 9.81

        // userAcceleration is gravity-free (in G units), convert to m/s²
        let ax = motion.userAcceleration.x * g
        let ay = motion.userAcceleration.y * g
        let az = motion.userAcceleration.z * g

        let gx = motion.rotationRate.x
        let gy = motion.rotationRate.y
        let gz = motion.rotationRate.z

        // Use attitude for pitch and roll (much more accurate than raw accel)
        let pitch = motion.attitude.pitch * 180.0 / .pi
        let roll = motion.attitude.roll * 180.0 / .pi

        let reading = SensorReading(
            accelX: ax,
            accelY: ay,
            accelZ: az,
            gyroX: gx,
            gyroY: gy,
            gyroZ: gz,
            pitch: pitch,
            roll: roll,
            timestamp: Date()
        )

        onReading?(reading)

        DispatchQueue.main.async {
            self.currentReading = reading
        }
    }
}
