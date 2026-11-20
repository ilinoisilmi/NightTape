import SwiftUI

@main
struct NightTapeApp: App {
    @StateObject private var engine = SessionEngine.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var alarm = AlarmManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(engine)
                .environmentObject(settings)
                .environmentObject(alarm)
                .preferredColorScheme(.dark)
        }
    }
}
