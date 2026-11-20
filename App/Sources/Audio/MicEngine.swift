import AVFoundation
import SoundAnalysis

/// Owns the AVAudioEngine input tap. Computes the RMS level, converts each
/// buffer to 16 kHz mono, feeds the SoundAnalysis stream analyzer and hands
/// the converted buffer to the session engine.
final class MicEngine {
    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private var converter: AVAudioConverter?
    private let outFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false
    )!
    private var framePosition: AVAudioFramePosition = 0

    /// Called on the audio thread with the 16 kHz buffer and a 0...1 level.
    var onBuffer: ((AVAudioPCMBuffer, Double) -> Void)?

    /// The analyzer exists only while running; the classifier attaches to it
    /// right after start().
    var currentAnalyzer: SNAudioStreamAnalyzer? { analyzer }

    func start() throws {
        let input = engine.inputNode
        let tapFormat = input.outputFormat(forBus: 0)
        guard tapFormat.sampleRate > 0, tapFormat.channelCount > 0 else {
            throw AudioSessionError.micUnavailable
        }
        analyzer = SNAudioStreamAnalyzer(format: tapFormat)
        converter = AVAudioConverter(from: tapFormat, to: outFormat)

        input.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let level = Self.rmsLevel(buffer)
            self.framePosition += AVAudioFramePosition(buffer.frameLength)
            if let a = self.analyzer {
                a.analyze(buffer, atAudioFramePosition: self.framePosition)
            }
            if let converted = self.convert(buffer) {
                self.onBuffer?(converted, level)
            }
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        analyzer = nil
        converter = nil
    }

    // MARK: - Conversion

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let conv = converter else { return nil }
        let ratio = outFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else {
            return nil
        }
        var error: NSError?
        var fed = false
        let status = conv.convert(to: out, error: &error) { _, inStatus in
            if fed {
                inStatus.pointee = .noDataNow
                return nil
            }
            fed = true
            inStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, out.frameLength > 0 else { return nil }
        return out
    }

    /// RMS mapped to 0...1: -60 dB -> 0.0, -10 dB -> 1.0.
    static func rmsLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let channels = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        let chans = Int(buffer.format.channelCount)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        for c in 0..<chans {
            let data = channels[c]
            for i in 0..<frames { sum += data[i] * data[i] }
        }
        let rms = sqrt(Double(sum) / Double(frames * max(chans, 1)))
        let db = 20 * log10(max(rms, 1e-7))
        return min(1, max(0, (db + 60) / 50))
    }
}
