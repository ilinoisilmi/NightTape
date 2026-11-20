import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var engine: SessionEngine
    @State private var sessions: [SleepSession] = []
    @State private var selected: SleepSession?

    private func reload() {
        sessions = SessionStore.shared.loadAll()
        engine.lastNight = sessions.first(where: { $0.endedAt != nil })
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.largeTitle)
                            .foregroundColor(Theme.dimText)
                        Text("No nights recorded yet.")
                            .foregroundColor(Theme.dimText)
                    }
                } else {
                    List {
                        ForEach(sessions) { s in
                            Button {
                                selected = s
                            } label: {
                                row(s)
                            }
                            .listRowBackground(Theme.cardBg)
                            .swipeActions {
                                Button(role: .destructive) {
                                    SessionStore.shared.delete(s)
                                    reload()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Your nights")
            .onAppear {
                reload()
            }
            .sheet(item: $selected) { s in
                MorningReportView(session: s, isModal: true)
                    .preferredColorScheme(.dark)
            }
        }
    }

    private func row(_ s: SleepSession) -> some View {
        let stats = NightStats.compute(s)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(s.startedAt.nightLabel)
                    .font(.headline)
                    .foregroundColor(.white)
                Text((s.totalAsleep.map { "slept \($0.hmString)" } ?? "no sleep detected")
                     + " · \(s.events.count) clips")
                    .font(.caption)
                    .foregroundColor(Theme.dimText)
            }
            Spacer()
            Text("\(stats.score)")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.accentGradient)
        }
        .contentShape(Rectangle())
    }
}
