import AppKit

final class PinWindowManager {
    static let shared = PinWindowManager()

    private var pinnedWindows: [PinWindow] = []

    private init() {}

    func pinImage(_ image: NSImage) {
        let pinWindow = PinWindow(image: image)
        pinnedWindows.append(pinWindow)

        let offset = CGFloat(pinnedWindows.count - 1) * 30
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowSize = pinWindow.frame.size
            let origin = NSPoint(
                x: screenFrame.midX - windowSize.width / 2 + offset,
                y: screenFrame.midY - windowSize.height / 2 - offset
            )
            pinWindow.setFrameOrigin(origin)
        }

        pinWindow.makeKeyAndOrderFront(nil)

        pinWindow.onClose = { [weak self, weak pinWindow] in
            guard let self, let pinWindow else { return }
            self.removePinWindow(pinWindow)
        }
    }

    func unpinAll() {
        let windows = pinnedWindows
        pinnedWindows.removeAll()
        for window in windows {
            window.animateOut {
                window.orderOut(nil)
            }
        }
    }

    private func removePinWindow(_ window: PinWindow) {
        pinnedWindows.removeAll { $0 === window }
    }
}
