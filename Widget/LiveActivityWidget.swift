import ActivityKit
import SwiftUI
import WidgetKit

/// Lock screen Live Activity: elapsed timer that ticks by itself
/// (Text(timerInterval:)) + audio bars refreshed from the app every ~3 s.
struct NightTapeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NightTapeActivityAttributes.self) { context in
            LockScreenLiveView(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.phase == "asleep"
                        ? "moon.zzz.fill" : "moon.haze")
                        .foregroundColor(Color(hex: 0xA78BFA))
                        .font(.title3)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startedAt...Date.distantFuture,
                         countsDown: false)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: 64, alignment: .trailing)
                        .foregroundStyle(Color.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phase == "asleep" ? "Asleep" : "Falling asleep")
                        .font(.caption)
                        .foregroundColor(Color(hex: 0x8E8E99))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    MiniBars(bars: context.state.bars)
                        .frame(height: 26)
                    if context.state.eventCount > 0 {
                        Text("\(context.state.eventCount) clip\(context.state.eventCount == 1 ? "" : "s") captured")
                            .font(.caption2)
                            .foregroundColor(Color(hex: 0x8E8E99))
                    }
                }
            } compactLeading: {
                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(Color(hex: 0xA78BFA))
            } compactTrailing: {
                Text(timerInterval: context.state.startedAt...Date.distantFuture,
                     countsDown: false)
                    .monospacedDigit()
                    .font(.caption2)
                    .frame(maxWidth: 50)
                    .foregroundStyle(Color(hex: 0x22D3EE))
            } minimal: {
                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(Color(hex: 0xA78BFA))
            }
        }
    }
}

private struct LockScreenLiveView: View {
    let context: ActivityViewContext<NightTapeActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label {
                    Text(context.state.phase == "asleep" ? "Asleep" : "Falling asleep")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: 0xA78BFA), Color(hex: 0x22D3EE)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                } icon: {
                    Image(systemName: "moon.zzz.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: 0xA78BFA))
                }
                Spacer()
                Text(timerInterval: context.state.startedAt...Date.distantFuture,
                     countsDown: false)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            MiniBars(bars: context.state.bars)
                .frame(height: 30)
            HStack {
                Text("NightTape is listening")
                    .font(.caption2)
                    .foregroundColor(Color(hex: 0x8E8E99))
                Spacer()
                Text("\(context.state.eventCount) clip\(context.state.eventCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(Color(hex: 0x8E8E99))
            }
        }
        .padding(16)
    }
}

/// Audio level bars for the Live Activity (separate target, tiny copy).
private struct MiniBars: View {
    let bars: [Double]

    var body: some View {
        Canvas { ctx, size in
            let data = bars.isEmpty ? [Double](repeating: 0.02, count: 24) : bars
            let n = data.count
            let slot = size.width / CGFloat(n)
            let barW = slot * 0.55
            for i in 0..<n {
                let v = CGFloat(max(0.02, min(1, data[i])))
                let h = max(3, v * size.height)
                let x = CGFloat(i) * slot + (slot - barW) / 2
                let y = (size.height - h) / 2
                let rect = CGRect(x: x, y: y, width: barW, height: h)
                let path = Path(roundedRect: rect, cornerRadius: barW / 2)
                let t = CGFloat(i) / CGFloat(max(1, n - 1))
                let color = Color(
                    red: 0.65 + (0.13 - 0.65) * t,
                    green: 0.55 + (0.83 - 0.55) * t,
                    blue: 0.98 + (0.93 - 0.98) * t
                )
                ctx.fill(path, with: .color(color))
            }
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
