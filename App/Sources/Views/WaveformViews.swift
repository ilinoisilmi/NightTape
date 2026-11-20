import SwiftUI

/// Vertical audio bars (the "little lines thing"). Used in the app and
/// mirrored on the lock screen Live Activity.
struct LiveBars: View {
    let bars: [Double]
    var height: CGFloat = 32

    var body: some View {
        Canvas { ctx, size in
            let n = max(1, bars.count)
            let slot = size.width / CGFloat(n)
            let barW = slot * 0.55
            for i in 0..<n {
                let v = CGFloat(max(0.02, min(1, bars[i])))
                let h = max(3, v * size.height)
                let x = CGFloat(i) * slot + (slot - barW) / 2
                let y = (size.height - h) / 2
                let rect = CGRect(x: x, y: y, width: barW, height: h)
                let path = Path(roundedRect: rect, cornerRadius: barW / 2)
                let t = CGFloat(i) / CGFloat(max(1, n - 1))
                let color = Color(
                    red: 0.487 + (0.134 - 0.487) * t,
                    green: 0.227 + (0.827 - 0.227) * t,
                    blue: 0.929 + (0.933 - 0.929) * t
                )
                ctx.fill(path, with: .color(color))
            }
        }
        .frame(height: height)
    }
}

/// Minute-by-minute activity across the whole night (morning report).
struct NightChart: View {
    let levels: [Double]

    var body: some View {
        Canvas { ctx, size in
            let n = max(1, levels.count)
            let slot = size.width / CGFloat(n)
            let barW = max(1.5, slot * 0.66)
            for i in 0..<n {
                let v = CGFloat(max(0.03, min(1, levels[i])))
                let h = v * size.height * 0.92
                let x = CGFloat(i) * slot + (slot - barW) / 2
                let rect = CGRect(x: x, y: size.height - h, width: barW, height: h)
                let path = Path(roundedRect: rect, cornerRadius: min(2, barW / 2))
                let t = CGFloat(i) / CGFloat(max(1, n - 1))
                let color = Color(
                    red: 0.487 + (0.134 - 0.487) * t,
                    green: 0.227 + (0.827 - 0.227) * t,
                    blue: 0.929 + (0.933 - 0.929) * t
                )
                ctx.fill(path, with: .color(color.opacity(0.9)))
            }
        }
        .frame(height: 64)
    }
}
