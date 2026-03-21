import SwiftUI

struct SensorReadingsView: View {
    let reading: SensorReading
    let phoneState: PhoneState

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("SENSORS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
                    .tracking(1)

                Spacer()

                Text(phoneState.rawValue)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(phoneState == .resting ? Theme.textTertiary : Theme.severityMedium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        phoneState == .resting
                            ? Theme.surfaceLight
                            : Theme.severityMedium.opacity(0.15)
                    )
                    .cornerRadius(3)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    sensorLine("aX", value: reading.accelX, unit: "m/s²")
                    sensorLine("aY", value: reading.accelY, unit: "m/s²")
                    sensorLine("aZ", value: reading.accelZ, unit: "m/s²")
                }

                VStack(alignment: .leading, spacing: 2) {
                    sensorLine("gX", value: reading.gyroX, unit: "r/s")
                    sensorLine("gY", value: reading.gyroY, unit: "r/s")
                    sensorLine("gZ", value: reading.gyroZ, unit: "r/s")
                }

                VStack(alignment: .leading, spacing: 2) {
                    sensorLine("P", value: reading.pitch, unit: "°")
                    sensorLine("R", value: reading.roll, unit: "°")
                    sensorLine("M", value: reading.accelMagnitude, unit: "m/s²")
                }
            }
        }
    }

    private func sensorLine(_ label: String, value: Double, unit: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.accent.opacity(0.6))
                .frame(width: 16, alignment: .leading)

            Text(String(format: "%+7.2f", value))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 58, alignment: .trailing)

            Text(unit)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Theme.textTertiary)
        }
    }
}
