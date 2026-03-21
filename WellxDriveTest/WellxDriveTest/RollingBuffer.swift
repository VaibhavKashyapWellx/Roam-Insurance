import Foundation

struct RollingBuffer<T> {
    private var buffer: [T]
    private var index: Int = 0
    private(set) var count: Int = 0
    let capacity: Int

    init(capacity: Int, defaultValue: T) {
        self.capacity = capacity
        self.buffer = Array(repeating: defaultValue, count: capacity)
    }

    mutating func append(_ value: T) {
        buffer[index] = value
        index = (index + 1) % capacity
        if count < capacity { count += 1 }
    }

    var isFull: Bool { count == capacity }

    var values: [T] {
        if count < capacity {
            return Array(buffer[0..<count])
        }
        return Array(buffer[index..<capacity]) + Array(buffer[0..<index])
    }

    var last: T? {
        guard count > 0 else { return nil }
        let lastIndex = index == 0 ? capacity - 1 : index - 1
        return buffer[lastIndex]
    }
}

extension RollingBuffer where T == Double {
    var mean: Double {
        guard count > 0 else { return 0 }
        return values.reduce(0, +) / Double(count)
    }

    var variance: Double {
        guard count > 1 else { return 0 }
        let m = mean
        return values.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(count - 1)
    }

    var max: Double {
        values.max() ?? 0
    }

    var min: Double {
        values.min() ?? 0
    }
}
