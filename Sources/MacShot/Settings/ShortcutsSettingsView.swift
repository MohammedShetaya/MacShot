import SwiftUI

struct ShortcutsSettingsView: View {
    @State private var showRecordingAlert = false
    @State private var recordingAction = ""

    private let shortcuts: [ShortcutAction] = [
        ShortcutAction(name: "Capture Area", defaultShortcut: "⇧⌘4"),
        ShortcutAction(name: "Capture Fullscreen", defaultShortcut: "⇧⌘3"),
        ShortcutAction(name: "Capture Window", defaultShortcut: "⇧⌘5"),
        ShortcutAction(name: "Scrolling Capture", defaultShortcut: "—"),
        ShortcutAction(name: "Self-Timer", defaultShortcut: "—"),
        ShortcutAction(name: "Toggle Desktop Icons", defaultShortcut: "—"),
    ]

    var body: some View {
        Form {
            Section("Keyboard Shortcuts") {
                ForEach(shortcuts) { action in
                    HStack {
                        Text(action.name)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(action.defaultShortcut)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.secondary.opacity(0.3))
                            )
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(action.defaultShortcut == "—" ? .secondary : .primary)

                        Button("Record") {
                            recordingAction = action.name
                            showRecordingAlert = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            Section {
                Text("Click \"Record\" then press the desired key combination to set a shortcut. Shortcuts using ⌘ are recommended.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Record Shortcut", isPresented: $showRecordingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Custom shortcut recording for \"\(recordingAction)\" will be available in a future update.")
        }
    }
}

private struct ShortcutAction: Identifiable {
    let id = UUID()
    let name: String
    let defaultShortcut: String
}
