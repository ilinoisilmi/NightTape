import Foundation
import ActivityKit

/// Shared between the app target and the widget extension target.
struct NightTapeActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        /// "falling-asleep" | "asleep"
        var phase: String
        var startedAt: Date
        /// 24 bars, each 0...1 — the recent audio level history.
        var bars: [Double]
        var eventCount: Int
    }

    var sessionID: String
}
