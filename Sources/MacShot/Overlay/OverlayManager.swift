import AppKit

final class OverlayManager {
    static let shared = OverlayManager()
    weak var appState: AppState?

    private var currentPanel: OverlayPanel?
    private var autoDismissTimer: Timer?
    private var mouseEnteredObserver: NSObjectProtocol?
    private var mouseExitedObserver: NSObjectProtocol?

    private let autoDismissDelay: TimeInterval = 5.0

    private init() {
        mouseEnteredObserver = NotificationCenter.default.addObserver(
            forName: .overlayMouseEntered, object: nil, queue: .main
        ) { [weak self] _ in
            self?.cancelAutoDismiss()
        }

        mouseExitedObserver = NotificationCenter.default.addObserver(
            forName: .overlayMouseExited, object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduleAutoDismiss()
        }
    }

    deinit {
        if let mouseEnteredObserver { NotificationCenter.default.removeObserver(mouseEnteredObserver) }
        if let mouseExitedObserver { NotificationCenter.default.removeObserver(mouseExitedObserver) }
    }

    func showOverlay(image: NSImage, captureType: CaptureType) {
        dismissOverlay()

        let panel = OverlayPanel(image: image, captureType: captureType, appState: appState)
        currentPanel = panel

        panel.animateIn()
        scheduleAutoDismiss()
    }

    func dismissOverlay() {
        cancelAutoDismiss()
        guard let panel = currentPanel else { return }
        currentPanel = nil
        panel.animateOut()
    }

    private func scheduleAutoDismiss() {
        cancelAutoDismiss()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissDelay, repeats: false) { [weak self] _ in
            self?.dismissOverlay()
        }
    }

    private func cancelAutoDismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
    }
}
