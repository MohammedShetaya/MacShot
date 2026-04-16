import AppKit
import Combine

final class CaptureManager: ObservableObject {
    static let shared = CaptureManager()

    weak var appState: AppState?
    var onCaptureCompleted: ((NSImage, CaptureType) -> Void)?

    private var areaCaptureWindow: AreaCaptureOverlayWindow?
    private var windowPicker: WindowPickerOverlay?
    private var fullscreenPicker: FullscreenPickerOverlay?
    private var scrollingController: ScrollingCaptureController?
    private let windowCaptureManager = WindowCaptureManager()
    private let selfTimerManager = SelfTimerManager()

    private init() {}

    // MARK: - Public Capture Methods

    func captureArea() {
        guard ensurePermission() else { return }
        prepareForCapture()
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
            self?.restoreAfterCapture()
        }

        areaCaptureWindow = overlay
        overlay.beginCapture()
    }

    func captureFullscreen() {
        guard ensurePermission() else { return }
        prepareForCapture()
        appState?.isCapturing = true

        let picker = FullscreenPickerOverlay()

        picker.onScreenSelected = { [weak self] screen in
            guard let self else { return }
            self.fullscreenPicker = nil

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let image = FullscreenCapture.capture(screen: screen) {
                    self.deliverCapture(image: image, type: .fullscreen)
                } else {
                    self.restoreAfterCapture()
                }
                self.appState?.isCapturing = false
            }
        }

        picker.onCancel = { [weak self] in
            self?.fullscreenPicker = nil
            self?.appState?.isCapturing = false
            self?.restoreAfterCapture()
        }

        fullscreenPicker = picker
        picker.beginPicking()
    }

    func captureWindow() {
        guard ensurePermission() else { return }
        prepareForCapture()
        appState?.isCapturing = true
        windowCaptureManager.appState = appState

        let picker = WindowPickerOverlay(windowCaptureManager: windowCaptureManager)

        picker.onWindowSelected = { [weak self] windowInfo in
            guard let self else { return }
            self.windowPicker = nil

            if let image = self.windowCaptureManager.captureWindow(windowInfo) {
                self.deliverCapture(image: image, type: .window)
            } else {
                self.restoreAfterCapture()
            }

            self.appState?.isCapturing = false
        }

        picker.onCancel = { [weak self] in
            self?.windowPicker = nil
            self?.appState?.isCapturing = false
            self?.restoreAfterCapture()
        }

        windowPicker = picker
        picker.beginPicking()
    }

    func captureScrolling() {
        guard ensurePermission() else { return }
        prepareForCapture()
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
            self?.restoreAfterCapture()
        }

        scrollingController = controller
        controller.begin()
    }

    func captureWithTimer(seconds: Int, mode: CaptureType) {
        guard ensurePermission() else { return }
        prepareForCapture()
        appState?.isCapturing = true

        selfTimerManager.startTimer(seconds: seconds, mode: mode, captureManager: self) { [weak self] in
            self?.appState?.isCapturing = false
        }
    }

    func cancelTimer() {
        selfTimerManager.cancel()
        appState?.isCapturing = false
        restoreAfterCapture()
    }

    // MARK: - Private

    private func prepareForCapture() {
        OverlayManager.shared.dismissOverlay()
        AnnotationEditorManager.shared.hideAllEditors()
    }

    private func restoreAfterCapture() {
        AnnotationEditorManager.shared.showAllEditors()
    }

    private func ensurePermission() -> Bool {
        guard PermissionManager.shared.hasScreenCapturePermission else {
            PermissionManager.shared.requestScreenCapturePermission()
            return false
        }
        return true
    }

    private func deliverCapture(image: NSImage, type: CaptureType) {
        restoreAfterCapture()
        playShutterSound()
        onCaptureCompleted?(image, type)

        let item = ScreenshotItem(image: image, timestamp: Date(), captureType: type)
        appState?.addScreenshot(item)
    }

    private static let shutterSound: NSSound? = {
        if let asset = NSDataAsset(name: "ShutterSound") {
            return NSSound(data: asset.data)
        }

        if let url = Bundle.main.url(forResource: "shutter", withExtension: "mp3") {
            return NSSound(contentsOf: url, byReference: false)
        }

        let bundleName = "MacShot_MacShot"
        for base in [Bundle.main.bundleURL, Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")] {
            let bundleURL = base.appendingPathComponent("\(bundleName).bundle")
            if let bundle = Bundle(url: bundleURL),
               let url = bundle.url(forResource: "shutter", withExtension: "mp3") {
                return NSSound(contentsOf: url, byReference: false)
            }
        }

        return nil
    }()

    private func playShutterSound() {
        guard appState?.playSoundOnCapture == true else { return }
        CaptureManager.shutterSound?.play()
    }
}
