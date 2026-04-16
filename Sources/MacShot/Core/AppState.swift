import SwiftUI
import AppKit

final class AppState: ObservableObject {
    @Published var recentScreenshots: [ScreenshotItem] = []
    @Published var isCapturing: Bool = false
    @Published var desktopIconsHidden: Bool = false

    @AppStorage("saveDirectory") var saveDirectory: String = NSSearchPathForDirectoriesInDomains(.picturesDirectory, .userDomainMask, true).first ?? "~/Pictures"
    @AppStorage("imageFormat") var imageFormat: ImageFormat = .png
    @AppStorage("showOverlayAfterCapture") var showOverlayAfterCapture: Bool = true
    @AppStorage("windowCaptureBackground") var windowCaptureBackground: WindowCaptureBackground = .wallpaper
    @AppStorage("windowCapturePadding") var windowCapturePadding: Double = 40.0
    @AppStorage("jpegQuality") var jpegQuality: Double = 0.9
    @AppStorage("selfTimerSeconds") var selfTimerSeconds: Int = 5

    func addScreenshot(_ item: ScreenshotItem) {
        DispatchQueue.main.async {
            self.recentScreenshots.insert(item, at: 0)
            if self.recentScreenshots.count > 20 {
                self.recentScreenshots.removeLast()
            }
        }
    }
}

struct ScreenshotItem: Identifiable {
    let id = UUID()
    let image: NSImage
    let timestamp: Date
    var filePath: URL?
    let captureType: CaptureType
}

enum CaptureType: String {
    case area = "Area"
    case fullscreen = "Fullscreen"
    case window = "Window"
    case scrolling = "Scrolling"
}

enum ImageFormat: String, CaseIterable {
    case png = "PNG"
    case jpeg = "JPEG"
    case tiff = "TIFF"
}

enum WindowCaptureBackground: String, CaseIterable {
    case wallpaper = "Wallpaper"
    case transparent = "Transparent"
    case solidColor = "Solid Color"
}
