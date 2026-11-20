import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var engine: SessionEngine
    @EnvironmentObject var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmNoAlarm = false
    @State private var alarmDate = Date()
    @State private var battery: (level: Double, charging: Bool) = (-1, false)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if let last = engine.lastNight {
                        lastNightCard(last)
                    }
                    alarmCard
                    batteryCard
                    focusCard
                    startButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("NightTape")
            .onAppear(perform: readBattery)
            .onChange(of: scenePhase) { phase, _ in
                if phase == .active { readBattery() }
            }
        }
    }

    private func readBattery() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        battery = (Double(UIDevice.current.batteryLevel),
                   UIDevice.current.batteryState == .charging
                       || UIDevice.current.batteryState == .full)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 42))
                .foregroundStyle(Theme.accentGradient)
                .padding(.top, 8)
            Text("Press start, put the phone down, wake up to the tape.")
                .font(.subheadline)
                .foregroundColor(Theme.dimText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func lastNightCard(_ night: SleepSession) -> some View {
        let stats = NightStats.compute(night)
        return NavigationLink {
            MorningReportView(session: night, isModal: false)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Last night", systemImage: "tape")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Theme.dimText)
                    Text("\(night.startedAt.nightLabel) — "
                         + (night.totalAsleep.map { $0.hmString } ?? "didn't fall asleep"))
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("\(stats.score)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.accentGradient)
                    Text("score")
                        .font(.caption2)
                        .foregroundColor(Theme.dimText)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var alarmCard: some View {
        VStack(spacing: 14) {
            Toggle(isOn: $settings.alarmEnabled) {
                Label("Wake alarm", systemImage: "alarm.fill")
                    .font(.headline)
            }
            .tint(Color(hex: 0xA78BFA))

            if settings.alarmEnabled {
                DatePicker(
                    "Alarm time",
                    selection: $alarmDate,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxHeight: 130)
                .onChange(of: alarmDate) { _, new in
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: new)
                    settings.alarmMinutes = (comps.hour ?? 7) * 60 + (comps.minute ?? 30)
                }

                Toggle(isOn: $settings.smartWake) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart wake window")
                            .font(.subheadline.weight(.medium))
                        Text("Wakes you up to \(settings.smartWakeWindow) min early if you're stirring")
                            .font(.caption)
                            .foregroundColor(Theme.dimText)
                    }
                }
                .tint(Color(hex: 0xA78BFA))
            }
        }
        .card()
        .onAppear {
            let cal = Calendar.current
            alarmDate = cal.date(
                bySettingHour: settings.alarmMinutes / 60,
                minute: settings.alarmMinutes % 60,
                second: 0, of: Date()
            ) ?? Date()
        }
    }

    private var batteryCard: some View {
        Group {
            if battery.level >= 0 {
                HStack(spacing: 10) {
                    Image(systemName: battery.charging
                        ? "battery.100.bolt" : "battery.75")
                        .foregroundColor(battery.charging ? .green : Theme.dimText)
                    Text(battery.charging
                        ? "Charging — perfect for the night."
                        : String(format: "Battery %d%% — plug in if you can. Recording auto-saves at 20%%.", Int(battery.level * 100)))
                        .font(.footnote)
                        .foregroundColor(Theme.dimText)
                    Spacer()
                }
                .card()
            }
        }
    }

    private var focusCard: some View {
        NavigationLink {
            FocusGuideView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "moon.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: 0xA78BFA))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Mute notifications all night")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text("One-time setup: Sleep Focus schedule")
                        .font(.caption)
                        .foregroundColor(Theme.dimText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.dimText)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        Button {
            if settings.alarmEnabled {
                engine.startSession()
            } else {
                confirmNoAlarm = true
            }
        } label: {
            Label("Start Sleep", systemImage: "record.circle")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Capsule().fill(Theme.accentGradient))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .confirmationDialog(
            "No alarm is set",
            isPresented: $confirmNoAlarm,
            titleVisibility: .visible
        ) {
            Button("Start without alarm") { engine.startSession() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't be woken up. Start anyway?")
        }
    }
}
