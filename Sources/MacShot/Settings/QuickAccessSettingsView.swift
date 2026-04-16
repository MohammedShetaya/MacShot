import SwiftUI

struct QuickAccessSettingsView: View {
    @EnvironmentObject var appState: AppState

    @AppStorage("quickAccessAutoDismissSeconds") private var autoDismissSeconds: Double = 5
    @AppStorage("quickAccessPosition") private var overlayPosition = OverlayPosition.bottomRight.rawValue
    @AppStorage("showCopyButton") private var showCopyButton = true
    @AppStorage("showSaveButton") private var showSaveButton = true
    @AppStorage("showPinButton") private var showPinButton = true
    @AppStorage("showAnnotateButton") private var showAnnotateButton = true

    var body: some View {
        Form {
            Section {
                Toggle("Show Quick Access overlay after capture", isOn: $appState.showOverlayAfterCapture)
            }

            Section("Auto-Dismiss") {
                HStack {
                    Text("Auto-dismiss after")
                    Slider(value: $autoDismissSeconds, in: 1...30, step: 1)
                    Text("\(Int(autoDismissSeconds))s")
                        .monospacedDigit()
                        .frame(width: 30, alignment: .trailing)
                }
            }

            Section("Position") {
                Picker("Overlay position", selection: Binding(
                    get: { OverlayPosition(rawValue: overlayPosition) ?? .bottomRight },
                    set: { overlayPosition = $0.rawValue }
                )) {
                    ForEach(OverlayPosition.allCases, id: \.self) { position in
                        Text(position.displayName).tag(position)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Visible Buttons") {
                Toggle("Show Copy button", isOn: $showCopyButton)
                Toggle("Show Save button", isOn: $showSaveButton)
                Toggle("Show Pin button", isOn: $showPinButton)
                Toggle("Show Annotate button", isOn: $showAnnotateButton)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

enum OverlayPosition: String, CaseIterable {
    case bottomLeft, bottomRight, topLeft, topRight

    var displayName: String {
        switch self {
        case .bottomLeft: return "Bottom-left"
        case .bottomRight: return "Bottom-right"
        case .topLeft: return "Top-left"
        case .topRight: return "Top-right"
        }
    }
}
