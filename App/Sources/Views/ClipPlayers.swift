import AVFoundation
import Combine
import Foundation
import SwiftUI

/// Plays one clip with a progress bar.
final class ClipPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    private var player: AVAudioPlayer?
    private var timer: Timer?

    func toggle(url: URL) {
        if let p = player, p.isPlaying, p.url == url {
            p.stop()
            stopTimer()
            isPlaying = false
            progress = 0
            return
        }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        player?.play()
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let p = self.player else { return }
            if p.duration > 0 {
                self.progress = p.currentTime / p.duration
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        progress = 0
        stopTimer()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0
        stopTimer()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

/// Plays every clip back to back — "the audiobook of your night".
final class NightTapePlayer: ObservableObject {
    @Published var isPlaying = false
    private var queue: AVQueuePlayer?
    private var endObserver: NSObjectProtocol?

    func start(urls: [URL]) {
        stop()
        guard !urls.isEmpty else { return }
        let items = urls.map { AVPlayerItem(url: $0) }
        let q = AVQueuePlayer(items: items)
        queue = q
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        q.play()
        isPlaying = true
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: items.last,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
        }
    }

    func stop() {
        queue?.pause()
        queue = nil
        isPlaying = false
        if let o = endObserver {
            NotificationCenter.default.removeObserver(o)
            endObserver = nil
        }
    }
}
