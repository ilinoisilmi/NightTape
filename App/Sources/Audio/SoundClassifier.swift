import AVFoundation
import Foundation
import SoundAnalysis

/// On-device sound classification via Apple's built-in 300+ class model.
final class SoundClassifier: NSObject, SNResultsObserver {
    /// Called on a SoundAnalysis queue with (raw label, confidence).
    var onLabel: ((String, Double) -> Void)?

    private var analyzer: SNAudioStreamAnalyzer?
    private var request: SNClassifySoundRequest?

    // Labels that mean "something worth clipping".
    static let interestingLabels: Set<String> = [
        "snoring", "snore", "speech", "conversation", "talking", "whispering",
        "laughing", "laughter", "laugh", "giggle", "coughing", "cough",
        "sneezing", "sneeze", "fart", "flatulence", "burping", "burp",
        "sighing", "sigh", "yawn", "yawning", "crying", "sobbing",
        "whimpering", "shouting", "yelling", "screaming", "singing", "humming",
        "music", "mumbling", "dog", "barking", "dog barking", "cat", "meow",
        "knocking", "door", "doorbell", "sniffing", "sniff", "teeth grinding",
        "bruxism", "groan", "groaning", "moan", "moaning",
    ]

    // Labels we never want as an event name.
    static let boringLabels: Set<String> = [
        "silence", "quiet", "background", "background noise", "noise", "static",
        "wind", "fan", "hum", "breathing", "breath", "hvac", "air conditioner",
        "rain", "traffic", "roadway noise", "engine", "pink noise",
    ]

    static func isInteresting(_ raw: String, confidence: Double) -> Bool {
        let l = raw.lowercased()
        if boringLabels.contains(l) { return false }
        if interestingLabels.contains(l) { return confidence >= 0.55 }
        return confidence >= 0.85
    }

    static func displayName(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    func attach(to analyzer: SNAudioStreamAnalyzer) throws {
        self.analyzer = analyzer
        let req = try SNClassifySoundRequest(identifier: SNClassifierIdentifierVersion2)
        req.windowDuration = CMTime(seconds: 1.5, preferredTimescale: 44_100)
        req.overlapFactor = 0.9
        try analyzer.add(req, withObserver: self)
        request = req
    }

    func detach() {
        if let a = analyzer, let r = request {
            a.remove(r)
        }
        analyzer = nil
        request = nil
    }

    // MARK: - SNResultsObserver

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let cr = result as? SNClassificationResult else { return }
        guard let top = cr.classifications.first, top.confidence > 0.5 else { return }
        onLabel?(top.identifier, Double(top.confidence))
    }
}
