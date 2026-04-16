import AppKit
import Combine

final class CaptureManager: ObservableObject {
    static let shared = CaptureManager()

    weak var appState: AppState?
    var onCaptureCompleted: ((NSImage, CaptureType) -> Void)?

    private var areaCaptureWindow: AreaCaptureOverlayWindow?
    private var windowPicker: WindowPickerOverlay?
    private var scrollingController: ScrollingCaptureController?
    private let windowCaptureManager = WindowCaptureManager()
    private let selfTimerManager = SelfTimerManager()

    private init() {}

    // MARK: - Public Capture Methods

    func captureArea() {
        guard ensurePermission() else { return }
        appState?.isCapturing = true

        let overlay = AreaCaptureOverlayWindow()

        overlay.onCapture = { [weak self] image in
            guard let self else { return }
            self.areaCaptureWindow = nil
            self.appState?.isCapturing = false
            self.deliverCapture(image: image, type: .area)
        }

        overlay.onCancel = { [weak self] in
            self?.areaCaptureWindow = nil
            self?.appState?.isCapturing = false
        }

        areaCaptureWindow = overlay
        overlay.beginCapture()
    }

    func captureFullscreen() {
        guard ensurePermission() else { return }
        appState?.isCapturing = true

        // Brief delay so the menu bar dismisses before capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }

            if let image = FullscreenCapture.capture() {
                self.deliverCapture(image: image, type: .fullscreen)
            }

            self.appState?.isCapturing = false
        }
    }

    func captureWindow() {
        guard ensurePermission() else { return }
        appState?.isCapturing = true
        windowCaptureManager.appState = appState

        let picker = WindowPickerOverlay(windowCaptureManager: windowCaptureManager)

        picker.onWindowSelected = { [weak self] windowInfo in
            guard let self else { return }
            self.windowPicker = nil

            if let image = self.windowCaptureManager.captureWindow(windowInfo) {
                self.deliverCapture(image: image, type: .window)
            }

            self.appState?.isCapturing = false
        }

        picker.onCancel = { [weak self] in
            self?.windowPicker = nil
            self?.appState?.isCapturing = false
        }

        windowPicker = picker
        picker.beginPicking()
    }

    func captureScrolling() {
        guard ensurePermission() else { return }
        appState?.isCapturing = true

        let controller = ScrollingCaptureController()

        controller.onCapture = { [weak self] image in
            guard let self else { return }
            self.scrollingController = nil
            self.appState?.isCapturing = false
            self.deliverCapture(image: image, type: .scrolling)
        }

        controller.onCancel = { [weak self] in
            self?.scrollingController = nil
            self?.appState?.isCapturing = false
        }

        scrollingController = controller
        controller.begin()
    }

    func captureWithTimer(seconds: Int, mode: CaptureType) {
        guard ensurePermission() else { return }
        appState?.isCapturing = true

        selfTimerManager.startTimer(seconds: seconds, mode: mode, captureManager: self) { [weak self] in
            self?.appState?.isCapturing = false
        }
    }

    func cancelTimer() {
        selfTimerManager.cancel()
        appState?.isCapturing = false
    }

    // MARK: - Private

    private func ensurePermission() -> Bool {
        guard PermissionManager.shared.hasScreenCapturePermission else {
            PermissionManager.shared.requestScreenCapturePermission()
            return false
        }
        return true
    }

    private func deliverCapture(image: NSImage, type: CaptureType) {
        onCaptureCompleted?(image, type)

        let item = ScreenshotItem(image: image, timestamp: Date(), captureType: type)
        appState?.addScreenshot(item)
    }
}
