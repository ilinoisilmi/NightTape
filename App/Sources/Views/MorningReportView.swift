import SwiftUI

struct MorningReportView: View {
    let session: SleepSession
    var isModal: Bool

    @EnvironmentObject var engine: SessionEngine
    @Environment(\.dismiss) private var dismiss
    @StateObject private var nightPlayer = NightTapePlayer()
    @StateObject private var clipPlayer = ClipPlayer()

    private var stats: NightStats { NightStats.compute(session) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    statsGrid
                    if session.minuteLevels.count > 4 {
                        chartCard
                    }
                    if !session.events.isEmpty {
                        playAllCard
                        eventList
                    } else {
                        emptyEvents
                    }
                    reasonFooter
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Your night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if isModal {
                            dismiss()
                        } else {
                            nightPlayer.stop()
                            clipPlayer.stop()
                            engine.dismissReport()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onDisappear {
            nightPlayer.stop()
            clipPlayer.stop()
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Good morning.")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(.white)
            Text("Last night, in your own voice.")
                .font(.subheadline)
                .foregroundColor(Theme.dimText)
        }
        .padding(.top, 12)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCell(value: "\(stats.score)", label: "Sleep score",
                     symbol: "sparkles")
            StatCell(
                value: stats.totalAsleep.map { $0.hmString } ?? "—",
                label: "Time asleep", symbol: "bed.double.fill"
            )
            StatCell(
                value: stats.fellAsleepAfter.map { $0.msString } ?? "—",
                label: "Fell asleep in", symbol: "timer"
            )
            StatCell(value: "\(stats.eventCount)", label: "Clips captured",
                     symbol: "waveform")
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity across the night")
                .font(.headline)
            NightChart(levels: session.minuteLevels)
            Text("Taller bars = more sound. Clusters around the alarm often mean light sleep.")
                .font(.caption)
                .foregroundColor(Theme.dimText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var playAllCard: some View {
        Button {
            if nightPlayer.isPlaying {
                nightPlayer.stop()
            } else {
                clipPlayer.stop()
                let urls = session.events.compactMap {
                    SessionStore.shared.clipURL(sessionID: session.id, event: $0)
                }
                nightPlayer.start(urls: urls)
            }
        } label: {
            Label(
                nightPlayer.isPlaying
                    ? "Stop playback"
                    : "Play your night (\(stats.eventCount) clips, \(stats.clipsDuration.msString))",
                systemImage: nightPlayer.isPlaying ? "stop.circle.fill" : "play.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(Theme.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(Theme.accentGradient))
        }
        .buttonStyle(.plain)
    }

    private var eventList: some View {
        VStack(spacing: 10) {
            ForEach(Array(session.events.enumerated()), id: \.element.id) { idx, event in
                EventCardView(
                    index: idx + 1,
                    event: event,
                    clipURL: SessionStore.shared.clipURL(sessionID: session.id, event: event),
                    player: clipPlayer
                )
            }
        }
    }

    private var emptyEvents: some View {
        VStack(spacing: 8) {
            Image(systemName: "zzz")
                .font(.largeTitle)
                .foregroundColor(Theme.dimText)
            Text("You were quiet as a stone. No clips were worth saving.")
                .font(.subheadline)
                .foregroundColor(Theme.dimText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    @ViewBuilder
    private var reasonFooter: some View {
        let text: String? = {
            switch session.endedReason {
            case "battery": return "Recording stopped early — battery hit 20%."
            case "interrupted": return "The app was closed before this night ended; data may be partial."
            default: return nil
            }
        }()
        if let text {
            Label(text, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct StatCell: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundColor(Color(hex: 0xA78BFA))
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

struct EventCardView: View {
    let index: Int
    let event: SleepEvent
    let clipURL: URL?
    @ObservedObject var player: ClipPlayer

    var body: some View {
        HStack(spacing: 14) {
            Button {
                guard let url = clipURL else { return }
                if player.isPlaying {
                    player.stop()
                }
                player.toggle(url: url)
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(Theme.accentGradient)
            }
            .buttonStyle(.plain)
            .disabled(clipURL == nil)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text("\(event.startDate.clockString) · \(event.duration.msString)"
                     + (event.confidence > 0 ? String(format: " · %d%%", Int(event.confidence * 100)) : ""))
                    .font(.caption)
                    .foregroundColor(Theme.dimText)
                if player.isPlaying {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule().fill(Theme.accentGradient)
                                .frame(width: geo.size.width * player.progress)
                        }
                    }
                    .frame(height: 3)
                }
            }

            Spacer()

            if let url = clipURL {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundColor(Theme.dimText)
                }
            }
        }
        .card()
    }
}
