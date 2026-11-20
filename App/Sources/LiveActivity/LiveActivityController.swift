import ActivityKit
import Foundation

/// Owns the lock-screen Live Activity: elapsed timer + audio level bars +
/// phase + clip count. Local updates every ~3 s (no push needed).
final class LiveActivityController {
    private var activity: Activity<NightTapeActivityAttributes>?
    private var startedAt = Date()

    func start(sessionID: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        startedAt = Date()
        let attrs = NightTapeActivityAttributes(sessionID: sessionID)
        let state = NightTapeActivityAttributes.ContentState(
            phase: "falling-asleep",
            startedAt: startedAt,
            bars: Array(repeating: 0.02, count: 24),
            eventCount: 0
        )
        do {
            activity = try Activity.request(
                attributes: attrs,
                content: ActivityContent(state: state, staleDate: nil)
            )
        } catch {
            print("LiveActivity request failed: \(error)")
        }
    }

    func update(phase: SleepPhase, startedAt: Date, bars: [Double], eventCount: Int) {
        guard let a = activity else { return }
        self.startedAt = startedAt
        let state = NightTapeActivityAttributes.ContentState(
            phase: phase == .asleep ? "asleep" : "falling-asleep",
            startedAt: startedAt,
            bars: bars,
            eventCount: eventCount
        )
        Task {
            await a.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end(finalPhase: SleepPhase, eventCount: Int) {
        guard let a = activity else { return }
        let state = NightTapeActivityAttributes.ContentState(
            phase: finalPhase == .asleep ? "asleep" : "falling-asleep",
            startedAt: startedAt,
            bars: [],
            eventCount: eventCount
        )
        activity = nil
        Task {
            await a.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }

    private func end() {
        if let a = activity {
            let state = NightTapeActivityAttributes.ContentState(
                phase: "asleep", startedAt: startedAt, bars: [], eventCount: 0
            )
            activity = nil
            Task {
                await a.end(ActivityContent(state: state, staleDate: nil),
                            dismissalPolicy: .immediate)
            }
        }
    }
}
