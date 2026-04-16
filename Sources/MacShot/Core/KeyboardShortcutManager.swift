import AppKit

final class KeyboardShortcutManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private weak var captureManager: CaptureManager?

    init(captureManager: CaptureManager) {
        self.captureManager = captureManager
    }

    func register() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }

    func unregister() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shiftCommand: NSEvent.ModifierFlags = [.shift, .command]

        guard flags == shiftCommand else { return false }

        switch event.keyCode {
        case 0x14: // kVK_ANSI_3 -> ⇧⌘3
            captureManager?.captureFullscreen()
            return true
        case 0x15: // kVK_ANSI_4 -> ⇧⌘4
            captureManager?.captureArea()
            return true
        case 0x17: // kVK_ANSI_5 -> ⇧⌘5
            captureManager?.captureWindow()
            return true
        default:
            return false
        }
    }

    deinit {
        unregister()
    }
}
