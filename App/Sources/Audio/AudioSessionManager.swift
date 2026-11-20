import AVFoundation

enum AudioSessionError: LocalizedError {
    case micUnavailable
    var errorDescription: String? {
        "No microphone input is available. Check that mic permission is granted."
    }
}

enum AudioSessionManager {
    /// Recording mode: mic active, plays nothing audible, keeps the app alive
    /// overnight via the background-audio entitlement.
    static func configureRecording() throws {
        let s = AVAudioSession.sharedInstance()
        try s.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP])
        try s.setPreferredSampleRate(48_000)
        try s.setPreferredIOBufferDuration(0.1)
        try s.setActive(true)
        // Prefer the built-in mic: if AirPods are connected their mic would be
        // picked by default and hear almost nothing from a nightstand.
        if let builtin = s.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try? s.setPreferredInput(builtin)
        }
    }

    /// Alarm mode: playback only, rings even when the ring/silent switch is on.
    static func configurePlayback() throws {
        let s = AVAudioSession.sharedInstance()
        try s.setCategory(.playback, mode: .default)
        try s.setActive(true)
    }
}

/// Loops a 1-second all-zero wav at volume 0. An actively playing session is
/// what keeps iOS from suspending the app while the screen is locked —
/// the mic tap alone is usually enough, but this makes it bulletproof.
final class KeepAlivePlayer {
    private var player: AVAudioPlayer?

    func start() {
        guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = 0
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
