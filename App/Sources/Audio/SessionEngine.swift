import AVFoundation
import Combine
import Foundation
import SwiftUI
import UIKit
import UserNotifications

/// Owns a night: mic -> detector/classifier/recorder -> Live Activity,
/// alarm, battery guard, persistence and UI state.
final class SessionEngine: ObservableObject {
    static let shared = SessionEngine()

    enum State {
        case idle
        case recording
        case ringing
        case report
    }

    // MARK: - Published UI state

    @Published var state: State = .idle
    @Published var phase: SleepPhase = .awake
    @Published var liveLevel: Double = 0
    @Published var bars: [Double] = Array(repeating: 0.02, count: 24)
    @Published var eventCount: Int = 0
    @Published var elapsed: TimeInterval = 0
    @Published var batteryLevel: Double = -1
    @Published var batteryCharging = false
    @Published var reportSession: SleepSession?
    @Published var lastNight: SleepSession?
    @Published var startError: String?

    // MARK: - Components

    private let settings = AppSettings.shared
    private let store = SessionStore.shared
    private let mic = MicEngine()
    private let classifier = SoundClassifier()
    private let liveActivity = LiveActivityController()
    private let keepAlive = KeepAlivePlayer()
    private var detector = SleepDetector(silenceMinutes: 10, silenceThreshold: 0.2)
    private var recorder: EventRecorder?
    private var ticker: Timer?

    private var session: SleepSession?
    private var nextAlarmDate: Date?
    private var audioQueueObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?

    // Audio-thread -> main-thread handoff.
    private let audioLock = NSLock()
    private var tapLevels: [Double] = []

    // 1 Hz aggregation.
    private var secondAccum: [Double] = []
    private var secondStart = Date()
    private var minuteAccum: [Double] = []
    private var persistCounter = 0
    private var laCounter = 0

    // MARK: - Init

    private init() {
        store.recoverInterrupted()
        store.cleanup(olderThanDays: AppSettings.shared.keepDays)
        lastNight = store.loadAll().first(where: { $0.endedAt != nil })

        // A 3 AM phone call must not kill the night.
        audioQueueObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            guard let self, self.state == .recording else { return }
            guard let info = note.userInfo,
                  let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            if type == .ended {
                let optRaw = (info[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
                let opts = AVAudioSession.InterruptionOptions(rawValue: optRaw)
                if opts.contains(.shouldResume) {
                    DispatchQueue.main.async { self.restartAudio() }
                }
            }
        }

        // Headphones unplugged etc. — restart the tap cleanly.
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self, self.state == .recording else { return }
            DispatchQueue.main.async { self.restartAudio() }
        }
    }

    deinit {
        if let o = audioQueueObserver { NotificationCenter.default.removeObserver(o) }
        if let o = routeObserver { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: - Session control

    func startSession() {
        guard state == .idle else { return }
        UIDevice.current.isBatteryMonitoringEnabled = true
        requestNotifications()

        do {
            try AudioSessionManager.configureRecording()
        } catch {
            startError = error.localizedDescription
            return
        }
        keepAlive.start()

        var s = SleepSession()
        s.startedAt = Date()
        let dir = store.beginSessionDir(s.id)
        recorder = EventRecorder(
            directory: dir,
            preRollSeconds: settings.preRollSeconds,
            startLevel: settings.eventLevelThreshold
        )

        detector = SleepDetector(
            silenceMinutes: settings.silenceMinutes,
            silenceThreshold: settings.silenceLevelThreshold
        )
        detector.onPhaseChange = { [weak self] phase in
            DispatchQueue.main.async { self?.handlePhaseChange(phase) }
        }

        classifier.onLabel = { [weak self] label, confidence in
            self?.recorder?.setClassifierLabel(label, confidence)
        }
        mic.onBuffer = { [weak self] buffer, level in
            self?.handleTap(buffer: buffer, level: level)
        }

        do {
            try mic.start()
            if let analyzer = mic.currentAnalyzer {
                try classifier.attach(to: analyzer)
            }
        } catch {
            stopEverything()
            startError = error.localizedDescription
            return
        }

        session = s
        store.save(s)
        nextAlarmDate = settings.alarmEnabled ? nextAlarmOccurrence(after: Date()) : nil

        phase = .awake
        bars = Array(repeating: 0.02, count: 24)
        eventCount = 0
        elapsed = 0
        secondAccum = []
        minuteAccum = []
        secondStart = Date()
        persistCounter = 0
        liveActivity.start(sessionID: s.id.uuidString)
        startTicker()
        state = .recording
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// User taps "I'm awake" or battery guard fires.
    func endSession(reason: String) {
        endRecording(reason: reason)
        state = .report
    }

    /// User taps Stop on the ringing alarm.
    func alarmStopped() {
        AlarmManager.shared.stop()
        state = .report
    }

    /// User closes the morning report.
    func dismissReport() {
        state = .idle
        reportSession = nil
        lastNight = store.loadAll().first(where: { $0.endedAt != nil })
    }

    /// Stop ringing, ring again in 5 minutes.
    func snoozeAlarm() {
        AlarmManager.shared.snooze(minutes: 5)
    }

    // MARK: - Alarm scheduling

    private func fireAlarm() {
        endRecording(reason: "alarm")
        AlarmManager.shared.ring()
        state = .ringing
    }

    private func nextAlarmOccurrence(after date: Date) -> Date {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        for dayOffset in 0...2 {
            let candidate = startOfDay
                .addingTimeInterval(Double(dayOffset) * 86400)
                .addingTimeInterval(Double(settings.alarmMinutes) * 60)
            if candidate > date.addingTimeInterval(5 * 60) {
                return candidate
            }
        }
        return date.addingTimeInterval(8 * 3600)
    }

    // MARK: - Teardown

    private func endRecording(reason: String) {
        ticker?.invalidate()
        ticker = nil
        mic.stop()
        classifier.detach()
        keepAlive.stop()

        guard var s = session else { return }
        if let final = recorder?.forceClose() {
            s.events.append(final)
        }
        for ev in recorder?.drainPendingEvents() ?? [] {
            s.events.append(ev)
        }
        s.endedAt = Date()
        s.endedReason = reason
        s.phase = phase
        session = nil
        recorder = nil
        store.save(s)
        reportSession = s
        lastNight = s
        eventCount = s.events.count
        liveActivity.end(finalPhase: s.phase, eventCount: s.events.count)
        UIDevice.current.isBatteryMonitoringEnabled = false
    }

    private func stopEverything() {
        ticker?.invalidate()
        ticker = nil
        mic.stop()
        classifier.detach()
        keepAlive.stop()
        recorder = nil
        session = nil
        UIDevice.current.isBatteryMonitoringEnabled = false
    }

    private func restartAudio() {
        guard state == .recording else { return }
        mic.stop()
        classifier.detach()
        do {
            try AudioSessionManager.configureRecording()
            try mic.start()
            if let analyzer = mic.currentAnalyzer {
                try classifier.attach(to: analyzer)
            }
        } catch {
            print("audio restart failed: \(error)")
        }
    }

    // MARK: - Audio thread

    private func handleTap(buffer: AVAudioPCMBuffer, level: Double) {
        audioLock.lock()
        tapLevels.append(level)
        audioLock.unlock()
        recorder?.offer(buffer: buffer, level: level, now: Date())
    }

    // MARK: - 1 Hz main loop

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard var s = session else { return }
        elapsed = Date().timeIntervalSince(s.startedAt)

        audioLock.lock()
        let levels = tapLevels
        tapLevels = []
        audioLock.unlock()

        let peak = levels.max() ?? 0
        liveLevel = peak
        if !levels.isEmpty {
            bars.removeFirst(max(0, bars.count - 23))
            bars.append(min(1, max(0.02, peak)))
        }

        for ev in recorder?.drainPendingEvents() ?? [] {
            s.events.append(ev)
            eventCount = s.events.count
        }

        // Collapse taps into whole seconds for the detector.
        secondAccum.append(contentsOf: levels)
        let now = Date()
        if now.timeIntervalSince(secondStart) >= 1.0 {
            if !secondAccum.isEmpty {
                let avg = secondAccum.reduce(0, +) / Double(secondAccum.count)
                detector.addSecond(level: avg, at: now)
                minuteAccum.append(avg)
            }
            secondAccum = []
            secondStart = now
        }
        if minuteAccum.count >= 60 {
            let m = minuteAccum.reduce(0, +) / Double(minuteAccum.count)
            s.minuteLevels.append(min(1, m))
            minuteAccum.removeAll(keepingCapacity: true)
        }
        session = s

        // Live Activity every ~3 s.
        laCounter += 1
        if laCounter >= 3 {
            laCounter = 0
            liveActivity.update(phase: phase, startedAt: s.startedAt,
                                bars: bars, eventCount: eventCount)
        }

        // Battery guard.
        batteryLevel = Double(UIDevice.current.batteryLevel)
        batteryCharging = (UIDevice.current.batteryState == .charging
            || UIDevice.current.batteryState == .full)
        if !batteryCharging, batteryLevel >= 0, batteryLevel <= 0.20 {
            postNotification(
                title: "NightTape — low battery",
                body: "Battery hit 20%. Your night so far was saved and recording stopped."
            )
            endSession(reason: "battery")
            return
        }

        // Alarm time reached?
        if let alarm = nextAlarmDate, now >= alarm {
            fireAlarm()
            return
        }

        // Smart wake: noise near the alarm = light sleep — wake now.
        if settings.alarmEnabled, settings.smartWake, let alarm = nextAlarmDate {
            let windowStart = alarm.addingTimeInterval(-Double(settings.smartWakeWindow) * 60)
            if now >= windowStart, now < alarm,
               detector.wasRecentlyActive(within: 120, now: now) {
                fireAlarm()
                return
            }
        }

        // Crash-safe persistence every 5 minutes.
        persistCounter += 1
        if persistCounter >= 300 {
            persistCounter = 0
            store.save(s)
        }
    }

    private func handlePhaseChange(_ newPhase: SleepPhase) {
        guard var s = session else { return }
        phase = newPhase
        s.phase = newPhase
        if newPhase == .asleep, s.sleepOnsetAt == nil {
            s.sleepOnsetAt = Date()
            postNotification(
                title: "NightTape",
                body: "You drifted off — the tape is rolling. 🎙️"
            )
        }
        recorder?.setAsleep(newPhase == .asleep)
        session = s
        store.save(s)
        liveActivity.update(phase: newPhase, startedAt: s.startedAt,
                             bars: bars, eventCount: eventCount)
    }

    // MARK: - Notifications

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
            _, _ in
        }
    }

    private func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let req = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }
}
