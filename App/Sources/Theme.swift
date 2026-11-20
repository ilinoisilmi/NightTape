import SwiftUI

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

enum Theme {
    static let purple = Color(hex: 0x7C3AED)
    static let cyan = Color(hex: 0x22D3EE)
    static let bg = Color.black
    static let cardBg = Color(hex: 0x121218)
    static let dimText = Color(hex: 0x8E8E99)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [purple, cyan], startPoint: .leading, endPoint: .trailing)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(Theme.cardBg)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

extension TimeInterval {
    /// "7h 12m", "43m", "2m 08s"
    var hmString: String {
        let t = Int(self)
        let h = t / 3600
        let m = (t % 3600) / 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
        return "\(m)m \(String(format: "%02d", t % 60))s"
    }

    var msString: String {
        let t = Int(self)
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

extension Date {
    var clockString: String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: self)
    }

    var nightLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: self)
    }
}

func minutesToClock(_ minutes: Int) -> String {
    String(format: "%02d:%02d", minutes / 60 % 24, minutes % 60)
}
