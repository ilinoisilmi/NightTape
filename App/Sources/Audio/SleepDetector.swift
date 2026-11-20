import Foundation

/// Silence-based sleep onset detection. Feed it one level value per second.
/// "Asleep" = the last N minutes were all below the silence threshold.
final class SleepDetector {
    private(set) var phase: SleepPhase = .awake
    private var secondLevels: [Double] = []
    private var lastActiveAt: Date?

    let silenceMinutes: Int
    let silenceThreshold: Double

    var onPhaseChange: ((SleepPhase) -> Void)?

    init(silenceMinutes: Int, silenceThreshold: Double) {
        self.silenceMinutes = max(1, silenceMinutes)
        self.silenceThreshold = silenceThreshold
    }

    func addSecond(level: Double, at date: Date = Date()) {
        secondLevels.append(level)
        let keep = (silenceMinutes + 2) * 60
        if secondLevels.count > keep {
            secondLevels.removeFirst(secondLevels.count - keep)
        }
        if level > silenceThreshold {
            lastActiveAt = date
        }
        if phase == .awake, secondLevels.count >= silenceMinutes * 60 {
            let window = secondLevels.suffix(silenceMinutes * 60)
            if window.allSatisfy({ $0 < silenceThreshold }) {
                phase = .asleep
                onPhaseChange?(.asleep)
            }
        }
    }

    /// True when a sound was heard within the last `seconds`.
    /// Used by smart wake: noise near the alarm = light sleep = good moment.
    func wasRecentlyActive(within seconds: TimeInterval, now: Date = Date()) -> Bool {
        guard let last = lastActiveAt else { return false }
        return now.timeIntervalSince(last) < seconds
    }

    func reset() {
        phase = .awake
        secondLevels.removeAll()
        lastActiveAt = nil
    }
}
