import SwiftUI
import UIKit

/// iOS does not let apps toggle Do Not Disturb. The recipe that works:
/// NightTape's own alarm rings even on silent, and a one-time Sleep Focus
/// schedule mutes everything else overnight.
struct FocusGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("Why this needs 2 minutes of setup", systemImage: "info.circle")
                    .font(.headline)
                Text("iOS never lets an app silence other apps' notifications — that's a hard sandbox rule. The combination below achieves the same result: the only thing that can make noise at night is NightTape's alarm.")
                    .font(.subheadline)
                    .foregroundColor(Theme.dimText)

                step(1, "Open Settings → Focus → Sleep",
                     "Or Settings → Focus on older iOS versions.")
                step(2, "Set a schedule, e.g. 23:00 – 07:30, every day",
                     "While Sleep Focus is on, calls and notifications are silenced.")
                step(3, "Under Apps, allow NightTape",
                     "Optional but recommended so NightTape's own notifications ('you drifted off') still show.")
                step(4, "Done — it repeats automatically every night",
                     "The alarm in NightTape plays through the silent switch on its own, no Focus needed for that part.")

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .font(.headline)
                        .foregroundStyle(Theme.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Theme.accentGradient))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Mute notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ n: Int, _ title: String, _ sub: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(n)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.bg)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.accentGradient))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(sub)
                    .font(.caption)
                    .foregroundColor(Theme.dimText)
            }
        }
    }
}
