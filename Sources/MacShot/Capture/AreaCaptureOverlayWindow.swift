import AppKit
import SwiftUI

final class AreaCaptureOverlayWindow: NSWindow {
    var onCapture: ((NSImage) -> Void)?
    var onCancel: (() -> Void)?

    private let overlayView: AreaCaptureOverlayView

    init() {
        overlayView = AreaCaptureOverlayView()

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
        contentView = overlayView

        overlayView.onSelectionComplete = { [weak self] rect in
            self?.captureRegion(rect)
        }
        overlayView.onCancel = { [weak self] in
            self?.dismiss()
            self?.onCancel?()
        }
    }

    func beginCapture() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.set()
    }

    private func captureRegion(_ rect: NSRect) {
        orderOut(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }

            let globalRect = NSRect(
                x: self.frame.origin.x + rect.origin.x,
                y: self.frame.origin.y + rect.origin.y,
                width: rect.width,
                height: rect.height
            )

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
                self.onCancel?()
                return
            }

            let image = NSImage(cgImage: cgImage, size: rect.size)
            self.onCapture?(image)
        }
    }

    private func dismiss() {
        NSCursor.arrow.set()
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Overlay NSView

private final class AreaCaptureOverlayView: NSView {
    var onSelectionComplete: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var selectionStart: NSPoint?
    private var currentMouseLocation: NSPoint = .zero
    private var selectionRect: NSRect?
    private var isSelecting = false

    private let dimmingColor = NSColor.black.withAlphaComponent(0.3)
    private let selectionBorderColor = NSColor.white
    private let dimensionFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
    private let guidelineColor = NSColor.white.withAlphaComponent(0.4)

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

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        dimmingColor.setFill()
        context.fill(bounds)

        if let selection = selectionRect, selection.width > 0, selection.height > 0 {
            drawSelection(selection, in: context)
        } else {
            drawCrosshairGuidelines(at: currentMouseLocation, in: context)
        }
    }

    private func drawSelection(_ selection: NSRect, in context: CGContext) {
        context.setBlendMode(.clear)
        context.fill(selection)
        context.setBlendMode(.normal)

        selectionBorderColor.setStroke()
        let borderPath = NSBezierPath(rect: selection)
        borderPath.lineWidth = 1.0
        borderPath.setLineDash([4, 4], count: 2, phase: 0)
        borderPath.stroke()

        drawSelectionGuidelines(selection, in: context)
        drawDimensionLabel(for: selection)
    }

    private func drawSelectionGuidelines(_ selection: NSRect, in context: CGContext) {
        guidelineColor.setStroke()
        let dashPattern: [CGFloat] = [2, 4]

        let topLine = NSBezierPath()
        topLine.move(to: NSPoint(x: selection.midX, y: selection.maxY))
        topLine.line(to: NSPoint(x: selection.midX, y: bounds.maxY))
        topLine.lineWidth = 0.5
        topLine.setLineDash(dashPattern, count: 2, phase: 0)
        topLine.stroke()

        let bottomLine = NSBezierPath()
        bottomLine.move(to: NSPoint(x: selection.midX, y: selection.minY))
        bottomLine.line(to: NSPoint(x: selection.midX, y: bounds.minY))
        bottomLine.lineWidth = 0.5
        bottomLine.setLineDash(dashPattern, count: 2, phase: 0)
        bottomLine.stroke()

        let leftLine = NSBezierPath()
        leftLine.move(to: NSPoint(x: selection.minX, y: selection.midY))
        leftLine.line(to: NSPoint(x: bounds.minX, y: selection.midY))
        leftLine.lineWidth = 0.5
        leftLine.setLineDash(dashPattern, count: 2, phase: 0)
        leftLine.stroke()

        let rightLine = NSBezierPath()
        rightLine.move(to: NSPoint(x: selection.maxX, y: selection.midY))
        rightLine.line(to: NSPoint(x: bounds.maxX, y: selection.midY))
        rightLine.lineWidth = 0.5
        rightLine.setLineDash(dashPattern, count: 2, phase: 0)
        rightLine.stroke()
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

    private func drawDimensionLabel(for selection: NSRect) {
        let w = Int(selection.width)
        let h = Int(selection.height)
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
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.75).setFill()
        bgPath.fill()

        let textOrigin = CGPoint(
            x: labelOrigin.x + padding,
            y: labelOrigin.y + padding
        )
        text.draw(at: textOrigin, withAttributes: attributes)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        selectionStart = location
        selectionRect = nil
        isSelecting = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = selectionStart else { return }
        let current = convert(event.locationInWindow, from: nil)

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)

        selectionRect = NSRect(x: x, y: y, width: w, height: h)
        currentMouseLocation = current
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let selection = selectionRect, selection.width > 2, selection.height > 2 else {
            selectionStart = nil
            selectionRect = nil
            isSelecting = false
            needsDisplay = true
            return
        }

        isSelecting = false
        onSelectionComplete?(selection)
    }

    override func mouseMoved(with event: NSEvent) {
        currentMouseLocation = convert(event.locationInWindow, from: nil)
        if !isSelecting {
            needsDisplay = true
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
