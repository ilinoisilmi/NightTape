import AVFoundation
import Foundation

/// Turns 16 kHz buffers + levels + classifier labels into saved .m4a event
/// clips. All entry points are called on the audio thread; a lock protects
/// the state that the main thread touches (drain / setters).
///
/// Event lifecycle:
///  - opens on a level spike or an interesting classifier label (only while
///    the user is detected as asleep),
///  - writes the pre-roll ring buffer first, then live audio,
///  - closes after `quietCloseSeconds` of quiet or `maxClipSeconds`.
final class EventRecorder {
    private struct Config {
        var startLevel: Double
        var stopLevel: Double
        var quietCloseSeconds: Double = 6
        var maxClipSeconds: Double = 60
        var cooldownSeconds: Double = 8
        var isAsleep: Bool = false
    }

    private var config: Config
    private let ring: RingBuffer
    private let directory: URL
    private let fileFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false
    )!

    private var writer: AVAudioFile?
    private var openEvent: SleepEvent?
    private var lastLoudAt: Date?
    private var closedAt: Date?
    private var lastLabel: (label: String, confidence: Double, at: Date)?

    private var pendingEvents: [SleepEvent] = []
    private let lock = NSLock()

    init(directory: URL, preRollSeconds: Int, startLevel: Double) {
        self.directory = directory
        self.config = Config(startLevel: startLevel, stopLevel: startLevel * 0.6)
        self.ring = RingBuffer(seconds: Double(max(3, preRollSeconds)) + 2, sampleRate: 16_000)
    }

    // MARK: - Main-thread setters

    func setAsleep(_ asleep: Bool) {
        lock.lock(); defer { lock.unlock() }
        config.isAsleep = asleep
    }

    func setThresholds(start: Double) {
        lock.lock(); defer { lock.unlock() }
        config.startLevel = start
        config.stopLevel = start * 0.6
    }

    func drainPendingEvents() -> [SleepEvent] {
        lock.lock(); defer { lock.unlock() }
        let events = pendingEvents
        pendingEvents = []
        return events
    }

    /// Closes the open clip (session end). Returns it if one was open.
    func forceClose(now: Date = Date()) -> SleepEvent? {
        lock.lock(); defer { lock.unlock() }
        guard var event = openEvent else { return nil }
        event.duration = now.timeIntervalSince(event.startDate)
        writer = nil
        openEvent = nil
        pendingEvents.append(event)
        return event
    }

    // MARK: - Audio thread

    func setClassifierLabel(_ label: String, _ confidence: Double, at date: Date = Date()) {
        lock.lock(); defer { lock.unlock() }
        lastLabel = (label, confidence, date)
    }

    func offer(buffer: AVAudioPCMBuffer, level: Double, now: Date) {
        lock.lock(); defer { lock.unlock() }
        ring.append(buffer)

        if var event = openEvent {
            write(buffer)
            event.peakLevel = max(event.peakLevel, level)
            if level >= config.stopLevel { lastLoudAt = now }
            let duration = now.timeIntervalSince(event.startDate)
            let quietFor = lastLoudAt.map { now.timeIntervalSince($0) } ?? 0
            if duration >= config.maxClipSeconds || quietFor > config.quietCloseSeconds {
                event.duration = duration
                writer = nil
                openEvent = nil
                closedAt = now
                pendingEvents.append(event)
                return
            }
            openEvent = event
            return
        }

        // Consider opening a new event.
        if let closed = closedAt, now.timeIntervalSince(closed) < config.cooldownSeconds { return }
        guard config.isAsleep else { return }

        let labelHit = freshInterestingLabel(now)
        let levelHit = level >= config.startLevel
        guard levelHit || labelHit else { return }

        var event = SleepEvent()
        event.startDate = now
        event.peakLevel = level
        if let l = lastLabel, now.timeIntervalSince(l.at) < 3,
           SoundClassifier.isInteresting(l.label, confidence: l.confidence) {
            event.label = SoundClassifier.displayName(l.label)
            event.confidence = l.confidence
        }

        let name = "clip-\(event.id.uuidString).m4a"
        do {
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 48_000,
            ]
            writer = try AVAudioFile(
                forWriting: directory.appendingPathComponent(name),
                settings: settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
            writePreRoll()
            write(buffer)
            event.clipFileName = name
            openEvent = event
            lastLoudAt = now
        } catch {
            writer = nil
        }
    }

    // MARK: - Writing

    private func write(_ buffer: AVAudioPCMBuffer) {
        guard let w = writer else { return }
        do {
            try w.write(from: buffer)
        } catch {
            writer = nil
        }
    }

    private func writePreRoll() {
        let samples = ring.snapshot()
        guard !samples.isEmpty else { return }
        let frames = AVAudioFrameCount(samples.count)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fileFormat, frameCapacity: frames) else { return }
        buf.frameLength = frames
        if let dst = buf.floatChannelData?[0] {
            samples.withUnsafeBufferPointer { src in
                if let base = src.baseAddress {
                    dst.update(from: base, count: samples.count)
                }
            }
        }
        write(buf)
    }

    private func freshInterestingLabel(_ now: Date) -> Bool {
        guard let l = lastLabel else { return false }
        guard now.timeIntervalSince(l.at) < 3 else { return false }
        return SoundClassifier.isInteresting(l.label, confidence: l.confidence)
    }
}
