import SwiftUI

struct ActiveSessionView: View {
    @EnvironmentObject var engine: SessionEngine
    @EnvironmentObject var settings: AppSettings
    @State private var confirmStop = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text(elapsedString)
                .font(.system(size: 64, weight: .light, design: .monospaced))
                .foregroundColor(.white)
                .monospacedDigit()

            Text(phaseText)
                .font(.headline)
                .foregroundStyle(Theme.accentGradient)

            LiveBars(bars: engine.bars, height: 56)
                .padding(.horizontal, 32)

            HStack(spacing: 20) {
                Label("\(engine.eventCount)", systemImage: "waveform")
                Label(engine.batteryText, systemImage: "battery.75")
            }
            .font(.subheadline)
            .foregroundColor(Theme.dimText)

            if settings.alarmEnabled {
                Label("Alarm at \(minutesToClock(settings.alarmMinutes))"
                      + (settings.smartWake ? " (smart wake on)" : ""),
                      systemImage: "alarm")
                    .font(.footnote)
                    .foregroundColor(Theme.dimText)
            }

            Spacer()

            VStack(spacing: 10) {
                Text("Lock your phone — recording continues.")
                    .font(.footnote)
                    .foregroundColor(Theme.dimText)
                Text("The waveform is live on your lock screen.")
                    .font(.footnote)
                    .foregroundColor(Theme.dimText)
            }

            Button {
                confirmStop = true
            } label: {
                Text("I'm awake — end the night")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .background(Theme.bg.ignoresSafeArea())
        .confirmationDialog("End the night?", isPresented: $confirmStop,
                            titleVisibility: .visible) {
            Button("End & see my tape", role: .destructive) {
                engine.endSession(reason: "manual")
            }
            Button("Keep recording", role: .cancel) {}
        }
    }

    private var elapsedString: String {
        let t = Int(engine.elapsed)
        return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
    }

    private var phaseText: String {
        switch engine.phase {
        case .awake: return "Falling asleep…"
        case .asleep: return "Asleep — the tape is rolling"
        }
    }
}

extension SessionEngine {
    var batteryText: String {
        if batteryLevel < 0 { return "--" }
        return "\(Int(batteryLevel * 100))%"
    }
}
