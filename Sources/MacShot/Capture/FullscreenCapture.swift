import AppKit

enum FullscreenCapture {
    static func capture(screen: NSScreen? = nil) -> NSImage? {
        let targetScreen = screen ?? NSScreen.main
        guard let targetScreen else { return nil }

        let displayID = targetScreen.displayID
        guard let cgImage = CGDisplayCreateImage(displayID) else { return nil }

        let size = targetScreen.frame.size
        return NSImage(cgImage: cgImage, size: size)
    }

    static func captureAllScreens() -> NSImage? {
        let screenRect = NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }
        let cgRect = CGRect(
            x: screenRect.origin.x,
            y: screenRect.origin.y,
            width: screenRect.width,
            height: screenRect.height
        )

        guard let cgImage = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else { return nil }

        return NSImage(cgImage: cgImage, size: screenRect.size)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? CGMainDisplayID()
    }
}

// MARK: - Fullscreen Picker Overlay

final class FullscreenPickerOverlay: NSWindow {
    var onScreenSelected: ((NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    private let pickerView: FullscreenPickerView

    init() {
        pickerView = FullscreenPickerView()
        let fullRect = NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }

        super.init(
            contentRect: fullRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .init(Int(CGShieldingWindowLevel()) - 1)
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = pickerView

        pickerView.onScreenSelected = { [weak self] screen in
            self?.orderOut(nil)
            NSCursor.arrow.set()
            self?.onScreenSelected?(screen)
        }
        pickerView.onCancel = { [weak self] in
            self?.orderOut(nil)
            NSCursor.arrow.set()
            self?.onCancel?()
        }
    }

    func beginPicking() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.set()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Fullscreen Picker NSView

private final class FullscreenPickerView: NSView {
    var onScreenSelected: ((NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    private var highlightedScreen: NSScreen?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseMoved, .activeAlways, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.15).setFill()
        bounds.fill()

        guard let screen = highlightedScreen else { return }

        let viewRect = screenFrameInViewCoords(screen)

        NSGraphicsContext.current?.cgContext.setBlendMode(.clear)
        NSColor.clear.setFill()
        viewRect.fill()
        NSGraphicsContext.current?.cgContext.setBlendMode(.normal)

        NSColor.systemBlue.withAlphaComponent(0.1).setFill()
        viewRect.fill()

        let border = NSBezierPath(rect: viewRect)
        border.lineWidth = 3.0
        NSColor.systemBlue.setStroke()
        border.stroke()

        drawScreenLabel(for: screen, in: viewRect)
    }

    private func drawScreenLabel(for screen: NSScreen, in viewRect: NSRect) {
        let labelText = screen.localizedName as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = labelText.size(withAttributes: attributes)
        let padding: CGFloat = 8
        let bgSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding * 2)

        let labelOrigin = CGPoint(
            x: viewRect.midX - bgSize.width / 2,
            y: viewRect.midY - bgSize.height / 2
        )

        let bgRect = NSRect(origin: labelOrigin, size: bgSize)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 6, yRadius: 6)
        NSColor.black.withAlphaComponent(0.75).setFill()
        bgPath.fill()

        labelText.draw(
            at: CGPoint(x: labelOrigin.x + padding, y: labelOrigin.y + padding),
            withAttributes: attributes
        )
    }

    private func screenFrameInViewCoords(_ screen: NSScreen) -> NSRect {
        guard let window = self.window else { return .zero }
        return NSRect(
            x: screen.frame.origin.x - window.frame.origin.x,
            y: screen.frame.origin.y - window.frame.origin.y,
            width: screen.frame.width,
            height: screen.frame.height
        )
    }

    // MARK: - Mouse Events

    override func mouseMoved(with event: NSEvent) {
        let globalPoint = NSEvent.mouseLocation
        highlightedScreen = NSScreen.screens.first { $0.frame.contains(globalPoint) }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        if let screen = highlightedScreen {
            onScreenSelected?(screen)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
