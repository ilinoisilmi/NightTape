import SwiftUI

struct AlarmRingingView: View {
    @EnvironmentObject var engine: SessionEngine
    @ObservedObject private var alarm = AlarmManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(Date(), style: .time)
                .font(.system(size: 72, weight: .light, design: .rounded))
                .foregroundColor(.white)

            Text(alarm.snoozeUntil == nil ? "Good morning." : "Five more minutes, then up.")
                .font(.headline)
                .foregroundStyle(Theme.accentGradient)

            if let s = engine.reportSession {
                let stats = NightStats.compute(s)
                Text(summaryLine(stats))
                    .font(.subheadline)
                    .foregroundColor(Theme.dimText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    engine.alarmStopped()
                } label: {
                    Label("Stop & hear my night", systemImage: "play.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().fill(Theme.accentGradient))
                }
                .buttonStyle(.plain)

                Button {
                    engine.snoozeAlarm()
                } label: {
                    Text("Snooze 5 min")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func summaryLine(_ stats: NightStats) -> String {
        var parts: [String] = []
        if let t = stats.totalAsleep {
            parts.append("You slept \(t.hmString)")
        }
        if stats.eventCount > 0 {
            parts.append("\(stats.eventCount) moment\(stats.eventCount == 1 ? "" : "s") captured")
        }
        if parts.isEmpty { return "Your tape is ready." }
        return parts.joined(separator: " · ")
    }
}
