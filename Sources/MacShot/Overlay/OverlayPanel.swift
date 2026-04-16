import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    private let panelSize = NSSize(width: 200, height: 140)
    private let margin: CGFloat = 16

    init(image: NSImage, captureType: CaptureType, appState: AppState?) {
        super.init(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        backgroundColor = .clear
        hasShadow = false
        isOpaque = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let overlayView = OverlayView(
            image: image,
            captureType: captureType,
            appState: appState,
            onDismiss: { [weak self] in
                self?.animateOut()
            }
        )

        let hosting = NSHostingView(rootView: overlayView)
        hosting.frame = NSRect(origin: .zero, size: panelSize)
        hosting.autoresizingMask = [.width, .height]

        let container = NSView(frame: NSRect(origin: .zero, size: panelSize))
        container.wantsLayer = true
        container.addSubview(hosting)

        contentView = container
    }

    func animateIn() {
        guard let screen = NSScreen.main else {
            makeKeyAndOrderFront(nil)
            return
        }

        let screenFrame = screen.visibleFrame
        let finalOrigin = NSPoint(
            x: screenFrame.origin.x + margin,
            y: screenFrame.origin.y + margin
        )
        let startOrigin = NSPoint(
            x: finalOrigin.x,
            y: finalOrigin.y - 30
        )

        setFrameOrigin(startOrigin)
        alphaValue = 0
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrameOrigin(finalOrigin)
            self.animator().alphaValue = 1
        }
    }

    func animateOut(completion: (() -> Void)? = nil) {
        let currentOrigin = frame.origin
        let targetOrigin = NSPoint(x: currentOrigin.x, y: currentOrigin.y - 20)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().setFrameOrigin(targetOrigin)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            completion?()
        })
    }
}
