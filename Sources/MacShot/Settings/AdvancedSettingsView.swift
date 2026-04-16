import SwiftUI

struct AdvancedSettingsView: View {
    @AppStorage("scaleRetinaTo1x") private var scaleRetinaTo1x = false
    @AppStorage("showCursorInScreenshots") private var showCursorInScreenshots = false
    @AppStorage("highlightClicks") private var highlightClicks = false

    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section("Retina") {
                Toggle("Scale Retina screenshots to 1x", isOn: $scaleRetinaTo1x)
                Text("When enabled, screenshots on Retina displays will be scaled to standard resolution.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Cursor") {
                Toggle("Show cursor in screenshots", isOn: $showCursorInScreenshots)
                Toggle("Highlight clicks", isOn: $highlightClicks)
                    .disabled(!showCursorInScreenshots)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Reset All Settings", role: .destructive) {
                        showResetConfirmation = true
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Reset All Settings", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all MacShot settings to their default values. This action cannot be undone.")
        }
    }

    private func resetAllSettings() {
        let domain = Bundle.main.bundleIdentifier ?? "com.macshot.app"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        scaleRetinaTo1x = false
        showCursorInScreenshots = false
        highlightClicks = false
    }
}
