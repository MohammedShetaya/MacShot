import AppKit
import SwiftUI

final class ScrollingCaptureController {
    var onCapture: ((NSImage) -> Void)?
    var onCancel: (() -> Void)?

    private var selectionWindow: ScrollingRegionSelector?
    private var controlBar: ScrollingControlBar?
    private var capturedFrames: [NSImage] = []
    private var captureRegion: CGRect = .zero
    private var isCapturing = false
    private var frameTimer: Timer?

    private let scrollAmount: Int32 = -3
    private let frameCaptureInterval: TimeInterval = 0.35
    private let maxFrames = 50
    private let overlapSearchHeight: CGFloat = 60

    func begin() {
        let selector = ScrollingRegionSelector()

        selector.onRegionSelected = { [weak self] rect in
            guard let self else { return }
            self.captureRegion = rect
            self.selectionWindow?.orderOut(nil)
            self.selectionWindow = nil
            self.startScrollingCapture()
        }
        selector.onCancel = { [weak self] in
            self?.cleanup()
            self?.onCancel?()
        }

        selectionWindow = selector
        selector.beginSelection()
    }

    func stop() {
        isCapturing = false
        frameTimer?.invalidate()
        frameTimer = nil
    }

    // MARK: - Scrolling Capture Logic

    private func startScrollingCapture() {
        capturedFrames = []
        isCapturing = true

        controlBar = ScrollingControlBar(
            onDone: { [weak self] in self?.finishCapture() },
            onCancel: { [weak self] in
                self?.stop()
                self?.cleanup()
                self?.onCancel?()
            }
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.captureInitialFrame()
            self?.beginScrollAndCapture()
        }
    }

    private func captureInitialFrame() {
        if let frame = captureRegionImage() {
            capturedFrames.append(frame)
        }
    }

    private func beginScrollAndCapture() {
        frameTimer = Timer.scheduledTimer(withTimeInterval: frameCaptureInterval, repeats: true) { [weak self] timer in
            guard let self, self.isCapturing else {
                timer.invalidate()
                return
            }

            self.simulateScroll()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                guard self.isCapturing else { return }
                guard let newFrame = self.captureRegionImage() else { return }

                if let lastFrame = self.capturedFrames.last,
                   self.framesAreIdentical(lastFrame, newFrame) {
                    self.finishCapture()
                    return
                }

                self.capturedFrames.append(newFrame)

                if self.capturedFrames.count >= self.maxFrames {
                    self.finishCapture()
                }
            }
        }
    }

    private func simulateScroll() {
        guard let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: scrollAmount,
            wheel2: 0,
            wheel3: 0
        ) else { return }

        scrollEvent.location = CGPoint(x: captureRegion.midX, y: captureRegion.midY)
        scrollEvent.post(tap: .cghidEventTap)
    }

    private func captureRegionImage() -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(
            captureRegion,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else { return nil }

        return NSImage(
            cgImage: cgImage,
            size: CGSize(width: captureRegion.width, height: captureRegion.height)
        )
    }

    private func finishCapture() {
        stop()
        controlBar?.dismiss()
        controlBar = nil

        guard !capturedFrames.isEmpty else {
            onCancel?()
            cleanup()
            return
        }

        if let stitched = stitchFrames(capturedFrames) {
            onCapture?(stitched)
        } else if let single = capturedFrames.first {
            onCapture?(single)
        }

        cleanup()
    }

    // MARK: - Frame Stitching

    private func stitchFrames(_ frames: [NSImage]) -> NSImage? {
        guard let first = frames.first else { return nil }
        if frames.count == 1 { return first }

        var strips: [NSImage] = [first]
        var totalHeight: CGFloat = first.size.height

        for i in 1..<frames.count {
            let overlap = findOverlap(between: frames[i - 1], and: frames[i])
            let croppedHeight = frames[i].size.height - overlap
            guard croppedHeight > 0 else { continue }

            if let cropped = cropImage(frames[i], fromTop: overlap) {
                strips.append(cropped)
                totalHeight += cropped.size.height
            }
        }

        let width = first.size.width
        let finalImage = NSImage(size: CGSize(width: width, height: totalHeight))

        finalImage.lockFocus()
        var yOffset = totalHeight
        for strip in strips {
            yOffset -= strip.size.height
            strip.draw(
                in: NSRect(x: 0, y: yOffset, width: width, height: strip.size.height),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
        }
        finalImage.unlockFocus()

        return finalImage
    }

    private func findOverlap(between previous: NSImage, and current: NSImage) -> CGFloat {
        guard let prevCG = previous.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let currCG = current.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let prevData = pixelData(for: prevCG),
              let currData = pixelData(for: currCG),
              prevCG.width == currCG.width
        else { return 0 }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let searchRows = min(
            Int(overlapSearchHeight * scale),
            min(prevCG.height, currCG.height) / 2
        )
        let width = prevCG.width
        let prevBytesPerRow = prevCG.bytesPerRow
        let currBytesPerRow = currCG.bytesPerRow
        let sampleStep = max(4, (width * 4) / 100)

        for offset in stride(from: searchRows, through: 4, by: -1) {
            var matchCount = 0
            let rowsToCheck = min(4, offset)

            for row in 0..<rowsToCheck {
                let prevRowStart = (prevCG.height - offset + row) * prevBytesPerRow
                let currRowStart = row * currBytesPerRow
                var rowMatch = true

                for col in stride(from: 0, to: width * 4, by: sampleStep) {
                    let pVal = prevData[prevRowStart + col]
                    let cVal = currData[currRowStart + col]
                    if abs(Int(pVal) - Int(cVal)) > 8 {
                        rowMatch = false
                        break
                    }
                }

                if rowMatch { matchCount += 1 }
            }

            if matchCount == rowsToCheck {
                return CGFloat(offset) / scale
            }
        }

        return 0
    }

    private func pixelData(for cgImage: CGImage) -> [UInt8]? {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data as Data?
        else { return nil }
        return Array(data)
    }

    private func cropImage(_ image: NSImage, fromTop cropAmount: CGFloat) -> NSImage? {
        guard cropAmount < image.size.height else { return nil }
        let newHeight = image.size.height - cropAmount
        let cropped = NSImage(size: CGSize(width: image.size.width, height: newHeight))
        cropped.lockFocus()
        image.draw(
            in: NSRect(x: 0, y: 0, width: image.size.width, height: newHeight),
            from: NSRect(x: 0, y: 0, width: image.size.width, height: newHeight),
            operation: .sourceOver,
            fraction: 1.0
        )
        cropped.unlockFocus()
        return cropped
    }

    private func framesAreIdentical(_ a: NSImage, _ b: NSImage) -> Bool {
        guard let aCG = a.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let bCG = b.cgImage(forProposedRect: nil, context: nil, hints: nil),
              aCG.width == bCG.width, aCG.height == bCG.height,
              let aData = pixelData(for: aCG),
              let bData = pixelData(for: bCG)
        else { return false }

        let totalBytes = min(aData.count, bData.count)
        let step = max(1, totalBytes / 200)

        for offset in stride(from: 0, to: totalBytes, by: step) {
            if abs(Int(aData[offset]) - Int(bData[offset])) > 4 {
                return false
            }
        }

        return true
    }

    private func cleanup() {
        selectionWindow?.orderOut(nil)
        selectionWindow = nil
        controlBar?.dismiss()
        controlBar = nil
        capturedFrames = []
    }
}

// MARK: - Region Selector (returns CGRect in screen CG coordinates)

private final class ScrollingRegionSelector: NSWindow {
    var onRegionSelected: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private let selectorView: ScrollingRegionSelectorView

    init() {
        selectorView = ScrollingRegionSelectorView()

        let screenFrame = NSScreen.main?.frame ?? .zero
        super.init(
            contentRect: screenFrame,
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
        contentView = selectorView

        selectorView.onSelectionComplete = { [weak self] nsRect in
            guard let screen = NSScreen.main else { return }
            // Convert from NS coordinates (bottom-left) to CG coordinates (top-left)
            let cgRect = CGRect(
                x: nsRect.origin.x,
                y: screen.frame.height - nsRect.maxY,
                width: nsRect.width,
                height: nsRect.height
            )
            self?.onRegionSelected?(cgRect)
        }
        selectorView.onCancel = { [weak self] in
            self?.onCancel?()
        }
    }

    func beginSelection() {
        makeKeyAndOrderFront(nil)
        NSCursor.crosshair.set()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class ScrollingRegionSelectorView: NSView {
    var onSelectionComplete: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var selectionStart: NSPoint?
    private var selectionRect: NSRect?
    private var currentMouse: NSPoint = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        if let sel = selectionRect, sel.width > 0, sel.height > 0 {
            NSGraphicsContext.current?.cgContext.setBlendMode(.clear)
            sel.fill()
            NSGraphicsContext.current?.cgContext.setBlendMode(.normal)

            let border = NSBezierPath(rect: sel)
            border.lineWidth = 2
            NSColor.systemOrange.setStroke()
            border.stroke()

            let label = "\(Int(sel.width)) × \(Int(sel.height))" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let size = label.size(withAttributes: attrs)
            let bgRect = NSRect(
                x: sel.midX - size.width / 2 - 4,
                y: sel.minY - size.height - 12,
                width: size.width + 8,
                height: size.height + 6
            )
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: bgRect, xRadius: 3, yRadius: 3).fill()
            label.draw(at: NSPoint(x: bgRect.minX + 4, y: bgRect.minY + 3), withAttributes: attrs)
        } else {
            NSColor.white.withAlphaComponent(0.4).setStroke()
            let v = NSBezierPath()
            v.move(to: NSPoint(x: currentMouse.x, y: bounds.minY))
            v.line(to: NSPoint(x: currentMouse.x, y: bounds.maxY))
            v.lineWidth = 0.5
            v.stroke()
            let h = NSBezierPath()
            h.move(to: NSPoint(x: bounds.minX, y: currentMouse.y))
            h.line(to: NSPoint(x: bounds.maxX, y: currentMouse.y))
            h.lineWidth = 0.5
            h.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        selectionStart = convert(event.locationInWindow, from: nil)
        selectionRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = selectionStart else { return }
        let current = convert(event.locationInWindow, from: nil)
        selectionRect = NSRect(
            x: min(start.x, current.x), y: min(start.y, current.y),
            width: abs(current.x - start.x), height: abs(current.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let sel = selectionRect, sel.width > 4, sel.height > 4 else {
            selectionRect = nil
            needsDisplay = true
            return
        }
        NSCursor.arrow.set()
        onSelectionComplete?(sel)
    }

    override func mouseMoved(with event: NSEvent) {
        currentMouse = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() }
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}

// MARK: - Scrolling Control Bar

private final class ScrollingControlBar {
    private var window: NSWindow?

    init(onDone: @escaping () -> Void, onCancel: @escaping () -> Void) {
        guard let screen = NSScreen.main else { return }

        let barWidth: CGFloat = 260
        let barHeight: CGFloat = 44
        let origin = CGPoint(
            x: screen.frame.midX - barWidth / 2,
            y: screen.frame.maxY - barHeight - 60
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: CGSize(width: barWidth, height: barHeight)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isFloatingPanel = true

        let hostingView = NSHostingView(rootView: ScrollingBarView(onDone: onDone, onCancel: onCancel))
        panel.contentView = hostingView
        panel.orderFront(nil)

        self.window = panel
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }
}

private struct ScrollingBarView: View {
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            ProgressView()
                .scaleEffect(0.7)
                .progressViewStyle(.circular)

            Text("Scrolling...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()

            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.accentColor)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(width: 260, height: 44)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }
}
