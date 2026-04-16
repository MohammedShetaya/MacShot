import AppKit

final class AnnotationEditorManager {
    static let shared = AnnotationEditorManager()
    private var currentWindow: AnnotationEditorWindow?

    private init() {}

    func openEditor(with image: NSImage) {
        currentWindow?.close()

        let window = AnnotationEditorWindow(image: image)
        currentWindow = window

        window.delegate = WindowCleanupDelegate.shared
        WindowCleanupDelegate.shared.onClose = { [weak self] in
            self?.currentWindow = nil
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openEditor(with url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            NSLog("AnnotationEditorManager: failed to load image at \(url.path)")
            return
        }
        openEditor(with: image)
    }
}

private class WindowCleanupDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowCleanupDelegate()
    var onClose: (() -> Void)?

    func windowWillClose(_ notification: Notification) {
        onClose?()
        onClose = nil
    }
}
