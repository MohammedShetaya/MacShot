import AppKit

final class WindowCaptureManager {
    weak var appState: AppState?

    struct WindowInfo {
        let windowID: CGWindowID
        let name: String
        let ownerName: String
        let bounds: CGRect
        let ownerPID: pid_t
        let isOnScreen: Bool
    }

    func listWindows() -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return windowList.compactMap { info -> WindowInfo? in
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"],
                  width > 0, height > 0,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { return nil }

            let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""
            let windowName = info[kCGWindowName as String] as? String ?? ""
            let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t ?? 0
            let isOnScreen = info[kCGWindowIsOnscreen as String] as? Bool ?? false

            if ownerName == "MacShot" { return nil }

            return WindowInfo(
                windowID: windowID,
                name: windowName,
                ownerName: ownerName,
                bounds: CGRect(x: x, y: y, width: width, height: height),
                ownerPID: ownerPID,
                isOnScreen: isOnScreen
            )
        }
    }

    func captureWindow(_ windowInfo: WindowInfo) -> NSImage? {
        let padding = appState?.windowCapturePadding ?? 40.0
        let background = appState?.windowCaptureBackground ?? .wallpaper

        guard let windowImage = CGWindowListCreateImage(
            windowInfo.bounds,
            .optionIncludingWindow,
            windowInfo.windowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else { return nil }

        let windowNSImage = NSImage(
            cgImage: windowImage,
            size: CGSize(width: windowInfo.bounds.width, height: windowInfo.bounds.height)
        )

        return applyBackgroundAndPadding(
            to: windowNSImage,
            windowBounds: windowInfo.bounds,
            padding: padding,
            background: background
        )
    }

    func windowUnderCursor(at screenPoint: NSPoint) -> WindowInfo? {
        let windows = listWindows()
        let primaryScreenHeight = NSScreen.screens[0].frame.height
        let cgPoint = CGPoint(x: screenPoint.x, y: primaryScreenHeight - screenPoint.y)

        return windows.first { $0.bounds.contains(cgPoint) }
    }

    // MARK: - Background & Padding

    private func applyBackgroundAndPadding(
        to image: NSImage,
        windowBounds: CGRect,
        padding: CGFloat,
        background: WindowCaptureBackground
    ) -> NSImage {
        guard padding > 0 else { return image }

        let finalSize = CGSize(
            width: image.size.width + padding * 2,
            height: image.size.height + padding * 2
        )

        let finalImage = NSImage(size: finalSize)
        finalImage.lockFocus()

        switch background {
        case .wallpaper:
            drawWallpaperBackground(in: NSRect(origin: .zero, size: finalSize), windowBounds: windowBounds, padding: padding)
        case .transparent:
            NSColor.clear.setFill()
            NSRect(origin: .zero, size: finalSize).fill()
        case .solidColor:
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: finalSize).fill()
        }

        let drawRect = NSRect(
            x: padding,
            y: padding,
            width: image.size.width,
            height: image.size.height
        )

        addShadow(in: drawRect)
        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        finalImage.unlockFocus()
        return finalImage
    }

    private func drawWallpaperBackground(in rect: NSRect, windowBounds: CGRect, padding: CGFloat) {
        let wallpaperRect = CGRect(
            x: windowBounds.origin.x - padding,
            y: windowBounds.origin.y - padding,
            width: rect.width,
            height: rect.height
        )

        if let wallpaperImage = CGWindowListCreateImage(
            wallpaperRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) {
            let nsWallpaper = NSImage(cgImage: wallpaperImage, size: rect.size)
            nsWallpaper.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            let gradient = NSGradient(colors: [
                NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.25, alpha: 1.0),
                NSColor(calibratedRed: 0.25, green: 0.20, blue: 0.35, alpha: 1.0),
            ])
            gradient?.draw(in: rect, angle: 135)
        }
    }

    private func addShadow(in rect: NSRect) {
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState()

        let shadowColor = NSColor.black.withAlphaComponent(0.5).cgColor
        context.setShadow(offset: CGSize(width: 0, height: -8), blur: 24, color: shadowColor)

        NSColor.white.setFill()
        let shadowPath = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        shadowPath.fill()

        context.restoreGState()
    }
}

// MARK: - Window Picker Overlay

final class WindowPickerOverlay: NSWindow {
    var onWindowSelected: ((WindowCaptureManager.WindowInfo) -> Void)?
    var onCancel: (() -> Void)?

    private let pickerView: WindowPickerView
    private let windowCaptureManager: WindowCaptureManager

    init(windowCaptureManager: WindowCaptureManager) {
        self.windowCaptureManager = windowCaptureManager
        self.pickerView = WindowPickerView(windowCaptureManager: windowCaptureManager)

        let fullRect = NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }

        super.init(
            contentRect: fullRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .init(Int(CGShieldingWindowLevel()))
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        contentView = pickerView

        pickerView.onWindowSelected = { [weak self] windowInfo in
            self?.orderOut(nil)
            NSCursor.arrow.set()
            self?.onWindowSelected?(windowInfo)
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

// MARK: - Window Picker NSView

private final class WindowPickerView: NSView {
    var onWindowSelected: ((WindowCaptureManager.WindowInfo) -> Void)?
    var onCancel: (() -> Void)?

    private let windowCaptureManager: WindowCaptureManager
    private var highlightedWindow: WindowCaptureManager.WindowInfo?
    private var currentMouseLocation: NSPoint = .zero

    init(windowCaptureManager: WindowCaptureManager) {
        self.windowCaptureManager = windowCaptureManager
        super.init(frame: .zero)
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

        guard let windowInfo = highlightedWindow else { return }

        let primaryScreenHeight = NSScreen.screens[0].frame.height
        let windowOrigin = self.window?.frame.origin ?? .zero

        let nsX = windowInfo.bounds.origin.x
        let nsY = primaryScreenHeight - windowInfo.bounds.origin.y - windowInfo.bounds.height

        let viewRect = NSRect(
            x: nsX - windowOrigin.x,
            y: nsY - windowOrigin.y,
            width: windowInfo.bounds.width,
            height: windowInfo.bounds.height
        )

        NSColor.clear.setFill()
        NSGraphicsContext.current?.cgContext.setBlendMode(.clear)
        viewRect.fill()
        NSGraphicsContext.current?.cgContext.setBlendMode(.normal)

        let highlightColor = NSColor.systemBlue
        highlightColor.withAlphaComponent(0.15).setFill()
        viewRect.fill()

        let border = NSBezierPath(rect: viewRect)
        border.lineWidth = 3.0
        highlightColor.setStroke()
        border.stroke()

        let labelText = windowInfo.ownerName as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = labelText.size(withAttributes: attributes)
        let padding: CGFloat = 6
        let bgSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding * 2)

        let labelOrigin = CGPoint(
            x: viewRect.midX - bgSize.width / 2,
            y: viewRect.maxY + 6
        )

        let bgRect = NSRect(origin: labelOrigin, size: bgSize)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.75).setFill()
        bgPath.fill()

        labelText.draw(
            at: CGPoint(x: labelOrigin.x + padding, y: labelOrigin.y + padding),
            withAttributes: attributes
        )
    }

    // MARK: - Mouse Events

    override func mouseMoved(with event: NSEvent) {
        currentMouseLocation = NSEvent.mouseLocation
        highlightedWindow = windowCaptureManager.windowUnderCursor(at: currentMouseLocation)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        if let windowInfo = highlightedWindow {
            onWindowSelected?(windowInfo)
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
