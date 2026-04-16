import AppKit
import SwiftUI

/// Coordinates one borderless overlay window per NSScreen so that an area
/// selection can be drawn seamlessly across every connected display.
///
/// macOS does not reliably render a single borderless NSWindow across multiple
/// screens, so we build a flat "canvas" by placing a dedicated overlay window
/// on each screen and sharing selection state in global screen coordinates.
final class AreaCaptureOverlayWindow {
    var onCapture: ((NSImage) -> Void)?
    var onCancel: (() -> Void)?

    private var overlayWindows: [AreaOverlayScreenWindow] = []
    private let state = AreaCaptureState()

    init() {
        state.onSelectionComplete = { [weak self] globalRect in
            self?.captureRegion(globalRect)
        }
        state.onCancel = { [weak self] in
            self?.dismiss()
            self?.onCancel?()
        }
        state.onStateChanged = { [weak self] in
            self?.refreshAllViews()
        }
    }

    func beginCapture() {
        dismiss()

        for screen in NSScreen.screens {
            let window = AreaOverlayScreenWindow(screen: screen, state: state)
            overlayWindows.append(window)
            window.orderFrontRegardless()
        }

        overlayWindows.first?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.set()
    }

    private func refreshAllViews() {
        for window in overlayWindows {
            window.contentView?.needsDisplay = true
        }
    }

    private func captureRegion(_ globalRect: NSRect) {
        hideWindows()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }

            let primaryScreenHeight = NSScreen.screens[0].frame.height
            let captureRect = CGRect(
                x: globalRect.origin.x,
                y: primaryScreenHeight - globalRect.maxY,
                width: globalRect.width,
                height: globalRect.height
            )

            guard let cgImage = CGWindowListCreateImage(
                captureRect,
                .optionOnScreenOnly,
                kCGNullWindowID,
                [.bestResolution, .boundsIgnoreFraming]
            ) else {
                self.tearDown()
                self.onCancel?()
                return
            }

            self.tearDown()
            let image = NSImage(cgImage: cgImage, size: globalRect.size)
            self.onCapture?(image)
        }
    }

    private func dismiss() {
        NSCursor.arrow.set()
        tearDown()
    }

    private func hideWindows() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
    }

    private func tearDown() {
        hideWindows()
        overlayWindows.removeAll()
    }
}

// MARK: - Shared Selection State

final class AreaCaptureState {
    /// The drag origin, stored in global screen coordinates.
    var selectionStart: NSPoint?
    /// The most recent mouse position, in global screen coordinates.
    var currentMouseLocation: NSPoint = .zero
    /// The active selection rectangle, in global screen coordinates.
    var selectionRect: NSRect?
    var isSelecting = false

    var onSelectionComplete: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?
    var onStateChanged: (() -> Void)?
}

// MARK: - Per-Screen Overlay Window

private final class AreaOverlayScreenWindow: NSWindow {
    init(screen: NSScreen, state: AreaCaptureState) {
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
        contentView = AreaCaptureOverlayView(state: state, screenFrame: screen.frame)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Overlay NSView

private final class AreaCaptureOverlayView: NSView {
    private let state: AreaCaptureState
    private let screenFrame: NSRect

    private let dimmingColor = NSColor.black.withAlphaComponent(0.3)
    private let selectionBorderColor = NSColor.white
    private let dimensionFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
    private let guidelineColor = NSColor.white.withAlphaComponent(0.4)

    init(state: AreaCaptureState, screenFrame: NSRect) {
        self.state = state
        self.screenFrame = screenFrame
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

    private func globalToView(_ point: NSPoint) -> NSPoint {
        NSPoint(x: point.x - screenFrame.origin.x, y: point.y - screenFrame.origin.y)
    }

    private func globalToView(_ rect: NSRect) -> NSRect {
        NSRect(
            x: rect.origin.x - screenFrame.origin.x,
            y: rect.origin.y - screenFrame.origin.y,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        dimmingColor.setFill()
        context.fill(bounds)

        if let selectionGlobal = state.selectionRect,
           selectionGlobal.width > 0, selectionGlobal.height > 0 {
            let selection = globalToView(selectionGlobal)
            drawSelection(selection, globalSelection: selectionGlobal, in: context)
        } else {
            let mouseGlobal = state.currentMouseLocation
            if screenFrame.contains(mouseGlobal) {
                drawCrosshairGuidelines(at: globalToView(mouseGlobal), in: context)
            }
        }
    }

    private func drawSelection(_ selection: NSRect, globalSelection: NSRect, in context: CGContext) {
        let visible = selection.intersection(bounds)
        if !visible.isNull && !visible.isEmpty {
            context.setBlendMode(.clear)
            context.fill(visible)
            context.setBlendMode(.normal)
        }

        selectionBorderColor.setStroke()
        let borderPath = NSBezierPath(rect: selection)
        borderPath.lineWidth = 1.0
        borderPath.setLineDash([4, 4], count: 2, phase: 0)
        borderPath.stroke()

        drawSelectionGuidelines(selection, in: context)
        drawDimensionLabel(for: selection, globalSelection: globalSelection)
    }

    private func drawSelectionGuidelines(_ selection: NSRect, in context: CGContext) {
        guidelineColor.setStroke()
        let dashPattern: [CGFloat] = [2, 4]

        let segments: [(NSPoint, NSPoint)] = [
            (NSPoint(x: selection.midX, y: selection.maxY), NSPoint(x: selection.midX, y: bounds.maxY)),
            (NSPoint(x: selection.midX, y: selection.minY), NSPoint(x: selection.midX, y: bounds.minY)),
            (NSPoint(x: selection.minX, y: selection.midY), NSPoint(x: bounds.minX, y: selection.midY)),
            (NSPoint(x: selection.maxX, y: selection.midY), NSPoint(x: bounds.maxX, y: selection.midY)),
        ]

        for segment in segments {
            let path = NSBezierPath()
            path.move(to: segment.0)
            path.line(to: segment.1)
            path.lineWidth = 0.5
            path.setLineDash(dashPattern, count: 2, phase: 0)
            path.stroke()
        }
    }

    private func drawCrosshairGuidelines(at point: NSPoint, in context: CGContext) {
        guidelineColor.setStroke()

        let vertical = NSBezierPath()
        vertical.move(to: NSPoint(x: point.x, y: bounds.minY))
        vertical.line(to: NSPoint(x: point.x, y: bounds.maxY))
        vertical.lineWidth = 0.5
        vertical.stroke()

        let horizontal = NSBezierPath()
        horizontal.move(to: NSPoint(x: bounds.minX, y: point.y))
        horizontal.line(to: NSPoint(x: bounds.maxX, y: point.y))
        horizontal.lineWidth = 0.5
        horizontal.stroke()
    }

    private func drawDimensionLabel(for selection: NSRect, globalSelection: NSRect) {
        let w = Int(globalSelection.width)
        let h = Int(globalSelection.height)
        let text = "\(w) × \(h)" as NSString

        let attributes: [NSAttributedString.Key: Any] = [
            .font: dimensionFont,
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attributes)
        let padding: CGFloat = 6
        let bgSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding * 2)

        var labelOrigin = CGPoint(
            x: selection.midX - bgSize.width / 2,
            y: selection.minY - bgSize.height - 8
        )

        if labelOrigin.y < bounds.minY + 4 {
            labelOrigin.y = selection.maxY + 8
        }
        labelOrigin.x = max(bounds.minX + 4, min(labelOrigin.x, bounds.maxX - bgSize.width - 4))

        let bgRect = NSRect(origin: labelOrigin, size: bgSize)
        guard bounds.intersects(bgRect) else { return }

        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.75).setFill()
        bgPath.fill()

        let textOrigin = CGPoint(
            x: labelOrigin.x + padding,
            y: labelOrigin.y + padding
        )
        text.draw(at: textOrigin, withAttributes: attributes)
    }

    // MARK: - Mouse Events (all coordinates kept in global screen space)

    override func mouseDown(with event: NSEvent) {
        let global = NSEvent.mouseLocation
        state.selectionStart = global
        state.selectionRect = nil
        state.currentMouseLocation = global
        state.isSelecting = true
        state.onStateChanged?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = state.selectionStart else { return }
        let current = NSEvent.mouseLocation

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)

        state.selectionRect = NSRect(x: x, y: y, width: w, height: h)
        state.currentMouseLocation = current
        state.onStateChanged?()
    }

    override func mouseUp(with event: NSEvent) {
        guard let selection = state.selectionRect,
              selection.width > 2, selection.height > 2 else {
            state.selectionStart = nil
            state.selectionRect = nil
            state.isSelecting = false
            state.onStateChanged?()
            return
        }

        state.isSelecting = false
        state.onSelectionComplete?(selection)
    }

    override func mouseMoved(with event: NSEvent) {
        state.currentMouseLocation = NSEvent.mouseLocation
        if !state.isSelecting {
            state.onStateChanged?()
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
