import SwiftUI
import AppKit
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState

    @AppStorage("launchAtLogin") private var launchAtLogin = false


    @AppStorage("fileNamingPattern") private var fileNamingPattern = "MacShot {date} at {time}"

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }

                Toggle("Show in Menu Bar", isOn: .constant(true))
                    .disabled(true)
            }

            Section("Save Location") {
                HStack {
                    Text(abbreviatedPath(appState.saveDirectory))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Choose…") {
                        chooseSaveDirectory()
                    }
                }
            }

            Section("Image Format") {
                Picker("Format", selection: $appState.imageFormat) {
                    ForEach(ImageFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.menu)

                if appState.imageFormat == .jpeg {
                    HStack {
                        Text("JPEG Quality")
                        Slider(value: $appState.jpegQuality, in: 0.1...1.0, step: 0.05)
                        Text("\(Int(appState.jpegQuality * 100))%")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            Section("Capture") {
                Toggle("Show overlay after capture", isOn: $appState.showOverlayAfterCapture)
                Toggle("Play sound on capture", isOn: $appState.playSoundOnCapture)
            }

            Section("File Naming") {
                TextField("Pattern", text: $fileNamingPattern)
                Text("Available tokens: {date}, {time}")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose a folder to save screenshots"

        if panel.runModal() == .OK, let url = panel.url {
            appState.saveDirectory = url.path
        }
    }

    private func abbreviatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = !enabled
            }
        }
    }
}
