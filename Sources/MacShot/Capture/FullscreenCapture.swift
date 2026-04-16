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

/// Coordinator that presents a borderless picker window on every connected
/// display so the user can hover any screen and click to capture it.
final class FullscreenPickerOverlay {
    var onScreenSelected: ((NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    private var pickerWindows: [FullscreenPickerWindow] = []

    func beginPicking() {
        tearDown()

        for screen in NSScreen.screens {
            let window = FullscreenPickerWindow(screen: screen)
            window.onScreenSelected = { [weak self] selected in
                guard let self else { return }
                self.finish()
                self.onScreenSelected?(selected)
            }
            window.onCancel = { [weak self] in
                guard let self else { return }
                self.finish()
                self.onCancel?()
            }
            pickerWindows.append(window)
            window.orderFrontRegardless()
        }

        pickerWindows.first?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.set()
    }

    private func finish() {
        NSCursor.arrow.set()
        tearDown()
    }

    private func tearDown() {
        for window in pickerWindows {
            window.orderOut(nil)
        }
        pickerWindows.removeAll()
    }
}

// MARK: - Per-Screen Picker Window

private final class FullscreenPickerWindow: NSWindow {
    var onScreenSelected: ((NSScreen) -> Void)?
    var onCancel: (() -> Void)?

    private let targetScreen: NSScreen

    init(screen: NSScreen) {
        self.targetScreen = screen

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: false)

        isOpaque = false
        backgroundColor = .clear
        level = .init(Int(CGShieldingWindowLevel()) - 1)
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = FullscreenPickerView(screen: screen)
        view.onScreenSelected = { [weak self] in
            guard let self else { return }
            self.onScreenSelected?(self.targetScreen)
        }
        view.onCancel = { [weak self] in
            self?.onCancel?()
        }
        contentView = view
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Picker NSView

private final class FullscreenPickerView: NSView {
    var onScreenSelected: (() -> Void)?
    var onCancel: (() -> Void)?

    private let screen: NSScreen
    private var isHovered = false

    init(screen: NSScreen) {
        self.screen = screen
        super.init(frame: NSRect(origin: .zero, size: screen.frame.size))
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect,
        ]
        let trackingArea = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.15).setFill()
        bounds.fill()

        guard isHovered else { return }

        NSGraphicsContext.current?.cgContext.setBlendMode(.clear)
        NSColor.clear.setFill()
        bounds.fill()
        NSGraphicsContext.current?.cgContext.setBlendMode(.normal)

        NSColor.systemBlue.withAlphaComponent(0.1).setFill()
        bounds.fill()

        let border = NSBezierPath(rect: bounds.insetBy(dx: 1.5, dy: 1.5))
        border.lineWidth = 3.0
        NSColor.systemBlue.setStroke()
        border.stroke()

        drawScreenLabel()
    }

    private func drawScreenLabel() {
        let labelText = screen.localizedName as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = labelText.size(withAttributes: attributes)
        let padding: CGFloat = 8
        let bgSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding * 2)

        let labelOrigin = CGPoint(
            x: bounds.midX - bgSize.width / 2,
            y: bounds.midY - bgSize.height / 2
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

    // MARK: - Mouse Events

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        if !isHovered {
            isHovered = true
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        onScreenSelected?()
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
