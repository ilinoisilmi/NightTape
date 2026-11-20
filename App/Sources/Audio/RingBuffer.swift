import AVFoundation

/// Fixed-size FIFO of 16 kHz mono float samples. Audio-thread only.
final class RingBuffer {
    private var data: [Float]
    private var writeIndex = 0
    private(set) var count = 0
    let capacity: Int

    init(seconds: Double, sampleRate: Double) {
        capacity = max(1, Int(seconds * sampleRate))
        data = [Float](repeating: 0, count: capacity)
    }

    func reset() {
        writeIndex = 0
        count = 0
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let ch = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        var start = 0
        if n > capacity { start = n - capacity }
        for i in start..<n {
            data[writeIndex] = ch[i]
            writeIndex = (writeIndex + 1) % capacity
        }
        count = min(capacity, count + (n - start))
    }

    /// Chronologically ordered copy of the buffered samples.
    func snapshot() -> [Float] {
        guard count > 0 else { return [] }
        let head = (writeIndex - count + capacity) % capacity
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            out[i] = data[(head + i) % capacity]
        }
        return out
    }
}
