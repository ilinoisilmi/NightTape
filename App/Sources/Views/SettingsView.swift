import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var storageMB: Double = 0
    @State private var confirmWipe = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Alarm") {
                    Toggle("Alarm enabled", isOn: $settings.alarmEnabled)
                    Stepper("Smart wake window: \(settings.smartWakeWindow) min",
                            value: $settings.smartWakeWindow, in: 10...60, step: 5)
                        .disabled(!settings.smartWake)
                    Toggle("Smart wake", isOn: $settings.smartWake)
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Mic sensitivity")
                            Spacer()
                            Text(sensitivityLabel)
                                .foregroundColor(Theme.dimText)
                        }
                        Slider(value: $settings.sensitivity, in: 0...1)
                    }
                } header: {
                    Text("Recording")
                } footer: {
                    Text("Higher sensitivity catches quieter sounds (sleep talking from far away) but may clip more noise. Start at default; check your first morning report.")
                }

                Section {
                    Stepper("Silence means asleep after: \(settings.silenceMinutes) min",
                            value: $settings.silenceMinutes, in: 3...30)
                    Stepper("Pre-roll: \(settings.preRollSeconds) s",
                            value: $settings.preRollSeconds, in: 3...30)
                } header: {
                    Text("Detection")
                } footer: {
                    Text("Pre-roll is how much audio before a sound is kept, so clips start with context instead of mid-word.")
                }

                Section {
                    Stepper("Keep nights: \(settings.keepDays) days",
                            value: $settings.keepDays, in: 1...365)
                    HStack {
                        Text("Storage used")
                        Spacer()
                        Text(String(format: "%.1f MB", storageMB))
                            .foregroundColor(Theme.dimText)
                    }
                    Button("Delete all nights", role: .destructive) {
                        confirmWipe = true
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("All audio stays on this device. Nothing is ever uploaded.")
                }

                Section("About") {
                    NavigationLink("How notifications get muted (Sleep Focus)") {
                        FocusGuideView()
                    }
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .onAppear {
                storageMB = Double(SessionStore.shared.storageSizeBytes()) / 1_000_000
            }
            .confirmationDialog("Delete every recorded night?",
                                isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    SessionStore.shared.deleteAll()
                    storageMB = 0
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var sensitivityLabel: String {
        switch settings.sensitivity {
        case ..<0.34: return "Loud sounds only"
        case ..<0.67: return "Balanced"
        default: return "Very sensitive"
        }
    }
}
