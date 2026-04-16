import SwiftUI
import AppKit

struct WallpaperSettingsView: View {
    @EnvironmentObject var appState: AppState

    @AppStorage("wallpaperMode") private var wallpaperMode = WallpaperMode.desktop.rawValue
    @AppStorage("customWallpaperPath") private var customWallpaperPath = ""
    @AppStorage("wallpaperColor") private var wallpaperColorHex = "#1A1A2E"
    @AppStorage("lockWallpaperAcrossSpaces") private var lockWallpaperAcrossSpaces = false

    @State private var plainColor: Color = .init(red: 0.1, green: 0.1, blue: 0.18)

    var body: some View {
        Form {
            Section("Window Screenshot Background") {
                Picker(selection: Binding(
                    get: { WallpaperMode(rawValue: wallpaperMode) ?? .desktop },
                    set: { wallpaperMode = $0.rawValue }
                )) {
                    Text("Desktop wallpaper").tag(WallpaperMode.desktop)
                    Text("Custom wallpaper").tag(WallpaperMode.custom)
                    Text("Plain color").tag(WallpaperMode.plainColor)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.radioGroup)

                if WallpaperMode(rawValue: wallpaperMode) == .custom {
                    HStack {
                        Text(customWallpaperPath.isEmpty ? "No file selected" : abbreviatedPath(customWallpaperPath))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundColor(customWallpaperPath.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Choose…") {
                            chooseCustomWallpaper()
                        }
                    }
                }

                if WallpaperMode(rawValue: wallpaperMode) == .plainColor {
                    ColorPicker("Background color", selection: $plainColor)
                        .onChange(of: plainColor) { newValue in
                            wallpaperColorHex = newValue.hexString
                        }
                }

                Toggle("Don't change the wallpaper when switching spaces", isOn: $lockWallpaperAcrossSpaces)
            }

            Section("Window Capture Style") {
                HStack(spacing: 20) {
                    stylePreview(
                        label: "With wallpaper",
                        isSelected: appState.windowCaptureBackground == .wallpaper,
                        background: .blue.opacity(0.3)
                    ) {
                        appState.windowCaptureBackground = .wallpaper
                    }

                    stylePreview(
                        label: "Transparent",
                        isSelected: appState.windowCaptureBackground == .transparent,
                        background: .clear
                    ) {
                        appState.windowCaptureBackground = .transparent
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Padding") {
                VStack(alignment: .leading) {
                    Slider(value: $appState.windowCapturePadding, in: 0...100, step: 1)
                    HStack {
                        Text("Min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Default")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Max")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            if let color = Color(hex: wallpaperColorHex) {
                plainColor = color
            }
        }
    }

    @ViewBuilder
    private func stylePreview(label: String, isSelected: Bool, background: Color, action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(background)
                    .frame(width: 120, height: 80)

                if background == .clear {
                    checkerboardPattern()
                        .frame(width: 120, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: 70, height: 50)
                    .shadow(radius: 2)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .onTapGesture(perform: action)

            Text(label)
                .font(.caption)
                .foregroundColor(isSelected ? .primary : .secondary)
        }
    }

    @ViewBuilder
    private func checkerboardPattern() -> some View {
        Canvas { context, size in
            let tileSize: CGFloat = 8
            for row in 0..<Int(size.height / tileSize) + 1 {
                for col in 0..<Int(size.width / tileSize) + 1 {
                    let isWhite = (row + col) % 2 == 0
                    let rect = CGRect(x: CGFloat(col) * tileSize, y: CGFloat(row) * tileSize, width: tileSize, height: tileSize)
                    context.fill(Path(rect), with: .color(isWhite ? .white : .gray.opacity(0.3)))
                }
            }
        }
    }

    private func chooseCustomWallpaper() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Select"
        panel.message = "Choose a custom wallpaper image"

        if panel.runModal() == .OK, let url = panel.url {
            customWallpaperPath = url.path
        }
    }

    private func abbreviatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

enum WallpaperMode: String {
    case desktop
    case custom
    case plainColor
}

extension Color {
    var hexString: String {
        guard let components = NSColor(self).usingColorSpace(.deviceRGB) else { return "#000000" }
        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
