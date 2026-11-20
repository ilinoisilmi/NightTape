import SwiftUI

struct RootView: View {
    @EnvironmentObject var engine: SessionEngine
    @ObservedObject private var alarm = AlarmManager.shared

    /// Full-screen alarm whenever it's ringing OR a snooze is counting down.
    private var alarmVisible: Bool {
        alarm.isRinging || (alarm.snoozeUntil != nil && engine.state == .ringing)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if alarmVisible {
                AlarmRingingView()
            } else {
                switch engine.state {
                case .idle:
                    MainTabView()
                case .recording:
                    ActiveSessionView()
                case .ringing, .report:
                    if let session = engine.reportSession {
                        MorningReportView(session: session, isModal: false)
                    } else {
                        MainTabView()
                    }
                }
            }
        }
        .alert("Can't start", isPresented: Binding(
            get: { engine.startError != nil },
            set: { if !$0 { engine.startError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(engine.startError ?? "")
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Sleep", systemImage: "moon.zzz.fill") }
            HistoryView()
                .tabItem { Label("Nights", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Color(hex: 0xA78BFA))
    }
}
