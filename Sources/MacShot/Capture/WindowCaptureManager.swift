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
        // Capture only the window contents. Any decorative padding /
        // gradient / shadow is applied later as a render-time feature in
        // the annotation editor (see AnnotationState.padding*). This keeps
        // the source capture clean - no surrounding wallpaper or other
        // app chrome bleeding into the screenshot.
        guard let windowImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowInfo.windowID,
            [.bestResolution, .boundsIgnoreFraming, .nominalResolution]
        ) ?? CGWindowListCreateImage(
            windowInfo.bounds,
            .optionIncludingWindow,
            windowInfo.windowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else { return nil }

        return NSImage(
            cgImage: windowImage,
            size: CGSize(width: windowImage.width, height: windowImage.height)
        )
    }

    func windowUnderCursor(at screenPoint: NSPoint) -> WindowInfo? {
        let windows = listWindows()
        let primaryScreenHeight = NSScreen.screens[0].frame.height
        let cgPoint = CGPoint(x: screenPoint.x, y: primaryScreenHeight - screenPoint.y)

        return windows.first { $0.bounds.contains(cgPoint) }
    }

}

// MARK: - Window Picker Overlay

/// Coordinator that spins up a borderless picker window on every connected
/// display so the user can hover any visible window (even ones that span
/// multiple screens) and click to capture it.
final class WindowPickerOverlay {
    var onWindowSelected: ((WindowCaptureManager.WindowInfo) -> Void)?
    var onCancel: (() -> Void)?

    private let windowCaptureManager: WindowCaptureManager
    private let state = WindowPickerState()
    private var pickerWindows: [WindowPickerScreenWindow] = []

    init(windowCaptureManager: WindowCaptureManager) {
        self.windowCaptureManager = windowCaptureManager

        state.onWindowSelected = { [weak self] windowInfo in
            guard let self else { return }
            self.finish()
            self.onWindowSelected?(windowInfo)
        }
        state.onCancel = { [weak self] in
            guard let self else { return }
            self.finish()
            self.onCancel?()
        }
        state.onStateChanged = { [weak self] in
            self?.refreshAllViews()
        }
    }

    func beginPicking() {
        tearDown()

        for screen in NSScreen.screens {
            let window = WindowPickerScreenWindow(
                screen: screen,
                state: state,
                windowCaptureManager: windowCaptureManager
            )
            pickerWindows.append(window)
            window.orderFrontRegardless()
        }

        pickerWindows.first?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.set()
    }

    private func refreshAllViews() {
        for window in pickerWindows {
            window.contentView?.needsDisplay = true
        }
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

// MARK: - Shared Picker State

final class WindowPickerState {
    var highlightedWindow: WindowCaptureManager.WindowInfo?

    var onWindowSelected: ((WindowCaptureManager.WindowInfo) -> Void)?
    var onCancel: (() -> Void)?
    var onStateChanged: (() -> Void)?
}

// MARK: - Per-Screen Picker Window

private final class WindowPickerScreenWindow: NSWindow {
    init(screen: NSScreen, state: WindowPickerState, windowCaptureManager: WindowCaptureManager) {
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

        contentView = WindowPickerView(
            state: state,
            screenFrame: screen.frame,
            windowCaptureManager: windowCaptureManager
        )
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Per-Screen Picker View

private final class WindowPickerView: NSView {
    private let state: WindowPickerState
    private let screenFrame: NSRect
    private let windowCaptureManager: WindowCaptureManager

    init(state: WindowPickerState, screenFrame: NSRect, windowCaptureManager: WindowCaptureManager) {
        self.state = state
        self.screenFrame = screenFrame
        self.windowCaptureManager = windowCaptureManager
        super.init(frame: NSRect(origin: .zero, size: screenFrame.size))
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

    /// Returns the highlighted window's rect in this view's local coordinates.
    /// The window bounds live in Core Graphics coordinates (top-left origin),
    /// so we convert to global NS coordinates first, then subtract this
    /// screen's origin.
    private func highlightedViewRect(for windowInfo: WindowCaptureManager.WindowInfo) -> NSRect {
        let primaryScreenHeight = NSScreen.screens[0].frame.height
        let globalX = windowInfo.bounds.origin.x
        let globalY = primaryScreenHeight - windowInfo.bounds.origin.y - windowInfo.bounds.height

        return NSRect(
            x: globalX - screenFrame.origin.x,
            y: globalY - screenFrame.origin.y,
            width: windowInfo.bounds.width,
            height: windowInfo.bounds.height
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.15).setFill()
        bounds.fill()

        guard let windowInfo = state.highlightedWindow else { return }

        let viewRect = highlightedViewRect(for: windowInfo)
        let visible = viewRect.intersection(bounds)
        guard !visible.isNull, !visible.isEmpty else { return }

        NSColor.clear.setFill()
        NSGraphicsContext.current?.cgContext.setBlendMode(.clear)
        visible.fill()
        NSGraphicsContext.current?.cgContext.setBlendMode(.normal)

        let highlightColor = NSColor.systemBlue
        highlightColor.withAlphaComponent(0.15).setFill()
        visible.fill()

        let border = NSBezierPath(rect: viewRect)
        border.lineWidth = 3.0
        highlightColor.setStroke()

        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(rect: bounds).setClip()
        border.stroke()
        NSGraphicsContext.current?.restoreGraphicsState()

        drawLabel(for: windowInfo, viewRect: viewRect)
    }

    private func drawLabel(for windowInfo: WindowCaptureManager.WindowInfo, viewRect: NSRect) {
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
        guard bounds.intersects(bgRect) else { return }

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
        let global = NSEvent.mouseLocation
        let newHighlight = windowCaptureManager.windowUnderCursor(at: global)

        if newHighlight?.windowID != state.highlightedWindow?.windowID {
            state.highlightedWindow = newHighlight
            state.onStateChanged?()
        }
    }

    override func mouseDown(with event: NSEvent) {
        if let windowInfo = state.highlightedWindow {
            state.onWindowSelected?(windowInfo)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            state.onCancel?()
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
