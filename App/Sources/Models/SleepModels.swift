import Foundation

enum SleepPhase: String, Codable {
    case awake
    case asleep
}

struct SleepEvent: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var label: String = "Sound"
    var confidence: Double = 0
    var startDate: Date = Date()
    var duration: TimeInterval = 0
    var peakLevel: Double = 0
    var clipFileName: String? = nil

    var isLabeled: Bool { label != "Sound" }
}

struct SleepSession: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var sleepOnsetAt: Date? = nil
    var endedAt: Date? = nil
    var phase: SleepPhase = .awake
    var events: [SleepEvent] = []
    /// "manual" | "alarm" | "battery" | "interrupted"
    var endedReason: String = "manual"
    /// Average level per minute across the night (0...1).
    var minuteLevels: [Double] = []

    var totalAsleep: TimeInterval? {
        guard let onset = sleepOnsetAt else { return nil }
        let end = endedAt ?? Date()
        return max(0, end.timeIntervalSince(onset))
    }

    var fellAsleepAfter: TimeInterval? {
        guard let onset = sleepOnsetAt else { return nil }
        return onset.timeIntervalSince(startedAt)
    }
}

struct NightStats {
    let totalAsleep: TimeInterval?
    let fellAsleepAfter: TimeInterval?
    let eventsByLabel: [String: Int]
    let eventCount: Int
    let clipsDuration: TimeInterval
    let score: Int

    /// Fun heuristic, not medical. ~7.5 h of quiet sleep scores high.
    static func compute(_ s: SleepSession) -> NightStats {
        var counts: [String: Int] = [:]
        var clipSeconds: Double = 0
        for e in s.events {
            counts[e.label, default: 0] += 1
            clipSeconds += e.duration
        }
        var score = 100
        if let t = s.totalAsleep {
            let hours = t / 3600
            score -= Int(min(40, abs(hours - 7.5) * 8))
        } else {
            score -= 30
        }
        score -= min(20, (counts["Snoring"] ?? 0) / 3)
        if let t = s.totalAsleep, t > 0 {
            let perHour = Double(s.events.count) / (t / 3600)
            if perHour > 6 { score -= Int(min(15, perHour - 6)) }
        }
        return NightStats(
            totalAsleep: s.totalAsleep,
            fellAsleepAfter: s.fellAsleepAfter,
            eventsByLabel: counts,
            eventCount: s.events.count,
            clipsDuration: clipSeconds,
            score: max(5, min(100, score))
        )
    }
}
