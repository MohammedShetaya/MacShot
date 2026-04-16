import AppKit

final class AnnotationEditorManager: NSObject, NSWindowDelegate {
    static let shared = AnnotationEditorManager()
    private var windows: [AnnotationEditorWindow] = []

    private override init() {
        super.init()
    }

    func openEditor(with image: NSImage) {
        let window = AnnotationEditorWindow(image: image)
        windows.append(window)
        window.delegate = self

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

    func hideAllEditors() {
        for window in windows {
            window.orderOut(nil)
        }
    }

    func showAllEditors() {
        for window in windows {
            window.orderFront(nil)
        }
    }

    func closeAllEditors() {
        for window in windows {
            window.close()
        }
        windows.removeAll()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? AnnotationEditorWindow else { return }
        windows.removeAll { $0 === window }
    }
}
