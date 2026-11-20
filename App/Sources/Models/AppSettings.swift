import Foundation
import Combine

/// User preferences, persisted to UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    @Published var alarmEnabled: Bool { didSet { d.set(alarmEnabled, forKey: "alarmEnabled") } }
    /// Minutes since midnight.
    @Published var alarmMinutes: Int { didSet { d.set(alarmMinutes, forKey: "alarmMinutes") } }
    @Published var smartWake: Bool { didSet { d.set(smartWake, forKey: "smartWake") } }
    /// Minutes before the alarm during which waking early is allowed.
    @Published var smartWakeWindow: Int { didSet { d.set(smartWakeWindow, forKey: "smartWakeWindow") } }
    /// 0 (only loud sounds) ... 1 (very sensitive).
    @Published var sensitivity: Double { didSet { d.set(sensitivity, forKey: "sensitivity") } }
    /// Minutes of silence before the user is considered asleep.
    @Published var silenceMinutes: Int { didSet { d.set(silenceMinutes, forKey: "silenceMinutes") } }
    /// Seconds of audio kept before an event trigger, saved into the clip.
    @Published var preRollSeconds: Int { didSet { d.set(preRollSeconds, forKey: "preRollSeconds") } }
    /// Nights older than this are auto-deleted.
    @Published var keepDays: Int { didSet { d.set(keepDays, forKey: "keepDays") } }

    /// Level (0...1) above which a sound becomes a saved clip.
    var eventLevelThreshold: Double { 0.30 + 0.35 * (1.0 - sensitivity) }
    /// Level below which a second counts as "silent" for sleep detection.
    var silenceLevelThreshold: Double { eventLevelThreshold * 0.5 }

    init() {
        alarmEnabled = d.object(forKey: "alarmEnabled") as? Bool ?? false
        alarmMinutes = d.object(forKey: "alarmMinutes") as? Int ?? 7 * 60 + 30
        smartWake = d.object(forKey: "smartWake") as? Bool ?? true
        smartWakeWindow = d.object(forKey: "smartWakeWindow") as? Int ?? 30
        sensitivity = d.object(forKey: "sensitivity") as? Double ?? 0.6
        silenceMinutes = d.object(forKey: "silenceMinutes") as? Int ?? 10
        preRollSeconds = d.object(forKey: "preRollSeconds") as? Int ?? 12
        keepDays = d.object(forKey: "keepDays") as? Int ?? 30
    }
}
