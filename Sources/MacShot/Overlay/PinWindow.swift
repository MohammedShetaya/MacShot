import AppKit
import SwiftUI

final class PinWindow: NSPanel {
    private let image: NSImage
    private let imageView: NSImageView
    private let closeButton: NSButton
    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowFrame: NSRect = .zero
    private var currentScale: CGFloat = 1.0
    private let minScale: CGFloat = 0.25
    private let maxScale: CGFloat = 4.0
    var onClose: (() -> Void)?

    init(image: NSImage) {
        self.image = image

        let maxDimension: CGFloat = 400
        let imageAspect = image.size.width / image.size.height
        let windowSize: NSSize
        if imageAspect > 1 {
            windowSize = NSSize(width: maxDimension, height: maxDimension / imageAspect)
        } else {
            windowSize = NSSize(width: maxDimension * imageAspect, height: maxDimension)
        }

        imageView = NSImageView()
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown

        closeButton = NSButton(image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")!,
                               target: nil, action: nil)
        closeButton.isBordered = false
        closeButton.isHidden = true
        closeButton.contentTintColor = .white
        closeButton.imageScaling = .scaleProportionallyUpOrDown
        let shadowFilter = NSShadow()
        shadowFilter.shadowColor = NSColor.black.withAlphaComponent(0.5)
        shadowFilter.shadowOffset = NSSize(width: 0, height: -1)
        shadowFilter.shadowBlurRadius = 3
        closeButton.shadow = shadowFilter

        super.init(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.nonactivatingPanel, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        backgroundColor = .clear
        hasShadow = true
        isOpaque = false
        animationBehavior = .utilityWindow
        contentAspectRatio = windowSize

        let containerView = PinContentView(frame: NSRect(origin: .zero, size: windowSize))
        containerView.autoresizingMask = [.width, .height]
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        containerView.layer?.masksToBounds = true
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor

        imageView.frame = containerView.bounds
        imageView.autoresizingMask = [.width, .height]
        containerView.addSubview(imageView)

        closeButton.frame = NSRect(x: 8, y: containerView.bounds.height - 28, width: 20, height: 20)
        closeButton.autoresizingMask = [.maxXMargin, .minYMargin]
        closeButton.target = self
        closeButton.action = #selector(closePin)
        containerView.addSubview(closeButton)

        contentView = containerView

        containerView.onDoubleClick = { [weak self] in
            self?.openInAnnotationEditor()
        }

        setupContextMenu()
    }

    func animateOut(completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: completion)
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.deltaY
        let scaleFactor: CGFloat = 1.0 - (delta * 0.03)
        let newScale = (currentScale * scaleFactor).clamped(to: minScale...maxScale)

        let ratio = newScale / currentScale
        currentScale = newScale

        let oldFrame = frame
        let newWidth = oldFrame.width * ratio
        let newHeight = oldFrame.height * ratio

        let mouseInScreen = NSEvent.mouseLocation
        let relX = (mouseInScreen.x - oldFrame.origin.x) / oldFrame.width
        let relY = (mouseInScreen.y - oldFrame.origin.y) / oldFrame.height
        let newX = mouseInScreen.x - relX * newWidth
        let newY = mouseInScreen.y - relY * newHeight

        let newFrame = NSRect(x: newX, y: newY, width: newWidth, height: newHeight)
        setFrame(newFrame, display: true, animate: false)
    }

    func showCloseButton() {
        closeButton.isHidden = false
    }

    func hideCloseButton() {
        closeButton.isHidden = true
    }

    @objc private func closePin() {
        animateOut { [weak self] in
            self?.orderOut(nil)
            self?.onClose?()
        }
    }

    @objc private func copyImage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    @objc private func saveImage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        panel.nameFieldStringValue = "MacShot \(formatter.string(from: Date()))@2x.png"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            if let tiffData = self.image.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                try? pngData.write(to: url)
            }
        }
    }

    @objc private func closeAllPins() {
        PinWindowManager.shared.unpinAll()
    }

    @objc private func openInAnnotationEditor() {
        AnnotationEditorManager.shared.openEditor(with: image)
    }

    private func setupContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(copyImage), keyEquivalent: "c").target = self
        menu.addItem(withTitle: "Save As…", action: #selector(saveImage), keyEquivalent: "s").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Annotate", action: #selector(openInAnnotationEditor), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Close", action: #selector(closePin), keyEquivalent: "w").target = self
        menu.addItem(withTitle: "Close All Pins", action: #selector(closeAllPins), keyEquivalent: "").target = self
        self.contentView?.menu = menu
    }
}

private class PinContentView: NSView {
    var onDoubleClick: (() -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = hoverTrackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        (window as? PinWindow)?.showCloseButton()
    }

    override func mouseExited(with event: NSEvent) {
        (window as? PinWindow)?.hideCloseButton()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        } else {
            super.mouseDown(with: event)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
