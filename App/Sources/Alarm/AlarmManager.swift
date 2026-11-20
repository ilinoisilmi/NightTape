import AVFoundation
import Combine
import Foundation
import UIKit

/// The alarm. Rings through the silent switch by switching the audio session
/// to .playback before starting the looping chime (with a gentle fade-in).
final class AlarmManager: ObservableObject {
    static let shared = AlarmManager()

    @Published var isRinging = false
    @Published var snoozeUntil: Date? = nil

    private var player: AVAudioPlayer?
    private var snoozeTimer: Timer?

    func ring() {
        stopSnoozeTimer()
        try? AudioSessionManager.configurePlayback()
        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "wav") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = 0.15
        player?.play()
        // Gentle wake: ramp from quiet to full over 8 seconds.
        player?.setVolume(1.0, fadeDuration: 8)
        isRinging = true
        snoozeUntil = nil
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func stop() {
        player?.stop()
        player = nil
        isRinging = false
        snoozeUntil = nil
        stopSnoozeTimer()
    }

    func snooze(minutes: Int = 5) {
        player?.stop()
        player = nil
        isRinging = false
        let until = Date().addingTimeInterval(Double(minutes) * 60)
        snoozeUntil = until
        snoozeTimer = Timer.scheduledTimer(withTimeInterval: Double(minutes) * 60, repeats: false) {
            [weak self] _ in
            self?.ring()
        }
    }

    private func stopSnoozeTimer() {
        snoozeTimer?.invalidate()
        snoozeTimer = nil
    }
}
