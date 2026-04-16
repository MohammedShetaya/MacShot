import SwiftUI
import AppKit

struct AnnotationCanvas: View {
    @ObservedObject var state: AnnotationState

    var body: some View {
        GeometryReader { geo in
            let viewSize = geo.size
            let imageSize = state.baseImage.size
            let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let imageOffset = CGPoint(
                x: (viewSize.width - scaledSize.width) / 2,
                y: (viewSize.height - scaledSize.height) / 2
            )

            ZStack {
                Color(nsColor: NSColor(white: 0.18, alpha: 1.0))

                Image(nsImage: state.baseImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                AnnotationDrawingLayer(
                    state: state,
                    scale: scale,
                    imageOffset: imageOffset,
                    scaledSize: scaledSize
                )
                .frame(width: scaledSize.width, height: scaledSize.height)
                .position(x: viewSize.width / 2, y: viewSize.height / 2)

                if state.currentTool == .crop {
                    CropOverlayView(state: state, imageSize: imageSize, viewSize: viewSize)
                } else {
                    AnnotationInteractionLayer(
                        state: state,
                        viewSize: viewSize,
                        imageSize: imageSize,
                        scale: scale,
                        imageOffset: imageOffset
                    )
                }
            }
        }
    }
}

// MARK: - Drawing Layer (renders committed + in-progress annotations)

struct AnnotationDrawingLayer: View {
    @ObservedObject var state: AnnotationState
    let scale: CGFloat
    let imageOffset: CGPoint
    let scaledSize: CGSize

    var body: some View {
        Canvas { context, size in
            let allItems: [AnnotationItem] = {
                var items = state.annotations
                if let active = state.activeAnnotation {
                    items.append(active)
                }
                return items
            }()

            for item in allItems {
                drawItem(item, in: &context, scale: scale)
            }

            if state.currentTool == .hand {
                for item in state.annotations where item.tool == .arrow || item.tool == .line {
                    drawEndpointHandles(for: item, in: &context, scale: scale)
                }
            }
        }
        .allowsHitTesting(false)

        ForEach(state.annotations) { item in
            if item.tool == .text, let text = item.text, !text.isEmpty {
                textOverlay(for: item)
            }
        }

        if let active = state.activeAnnotation, active.tool == .text {
            textEditOverlay(for: active)
        }
    }

    private func drawEndpointHandles(for item: AnnotationItem, in context: inout GraphicsContext, scale: CGFloat) {
        let handleRadius: CGFloat = 5
        let startPt = scaled(item.startPoint, scale: scale)
        let endPt = scaled(item.endPoint, scale: scale)

        for pt in [startPt, endPt] {
            let rect = CGRect(x: pt.x - handleRadius, y: pt.y - handleRadius, width: handleRadius * 2, height: handleRadius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.white))
            context.stroke(Path(ellipseIn: rect), with: .color(.accentColor), lineWidth: 1.5)
        }
    }

    // MARK: - Per-item drawing

    private func drawItem(_ item: AnnotationItem, in context: inout GraphicsContext, scale: CGFloat) {
        let color = Color(nsColor: item.color)
        let lw = item.lineWidth * scale

        switch item.tool {
        case .rectangle:
            let rect = scaledRect(from: item.startPoint, to: item.endPoint, scale: scale)
            context.stroke(Path(rect), with: .color(color), lineWidth: lw)

        case .roundedRectangle:
            let rect = scaledRect(from: item.startPoint, to: item.endPoint, scale: scale)
            let path = Path(roundedRect: rect, cornerRadius: item.cornerRadius * scale)
            context.stroke(path, with: .color(color), lineWidth: lw)

        case .filledRectangle:
            let rect = scaledRect(from: item.startPoint, to: item.endPoint, scale: scale)
            context.fill(Path(rect), with: .color(color))

        case .circle:
            let rect = scaledRect(from: item.startPoint, to: item.endPoint, scale: scale)
            context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: lw)

        case .line:
            var path = Path()
            path.move(to: scaled(item.startPoint, scale: scale))
            path.addLine(to: scaled(item.endPoint, scale: scale))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))

        case .arrow:
            drawArrow(item, in: &context, scale: scale, color: color, lw: lw)

        case .text:
            break // handled by overlays

        case .blur:
            let rect = scaledRect(from: item.startPoint, to: item.endPoint, scale: scale)
            context.fill(Path(rect), with: .color(Color.gray.opacity(0.35)))

        case .counter:
            drawCounter(item, in: &context, scale: scale, color: color)

        case .highlight:
            guard item.points.count >= 2 else { return }
            var path = Path()
            path.move(to: scaled(item.points[0], scale: scale))
            for i in 1..<item.points.count {
                path.addLine(to: scaled(item.points[i], scale: scale))
            }
            let highlightColor = Color(nsColor: item.color).opacity(0.35)
            context.stroke(path, with: .color(highlightColor), style: StrokeStyle(lineWidth: 20 * scale, lineCap: .round, lineJoin: .round))

        case .pencil:
            guard item.points.count >= 2 else { return }
            var path = Path()
            path.move(to: scaled(item.points[0], scale: scale))
            for i in 1..<item.points.count {
                path.addLine(to: scaled(item.points[i], scale: scale))
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))

        case .crop, .hand:
            break
        }
    }

    private func drawArrow(_ item: AnnotationItem, in context: inout GraphicsContext, scale: CGFloat, color: Color, lw: CGFloat) {
        let start = scaled(item.startPoint, scale: scale)
        let end = scaled(item.endPoint, scale: scale)
        let style = item.arrowStyle

        // Draw shaft
        switch style {
        case .curvedRight, .curvedLeft:
            let controlPoint = curvedControlPoint(from: start, to: end, style: style, scale: scale)
            var shaft = Path()
            shaft.move(to: start)
            shaft.addQuadCurve(to: end, control: controlPoint)
            context.stroke(shaft, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        default:
            var shaft = Path()
            shaft.move(to: start)
            shaft.addLine(to: end)
            context.stroke(shaft, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }

        // Draw arrowhead(s)
        let headLength: CGFloat = max(12 * scale, lw * 4)

        let endAngle: CGFloat
        if style == .curvedRight || style == .curvedLeft {
            let cp = curvedControlPoint(from: start, to: end, style: style, scale: scale)
            endAngle = atan2(end.y - cp.y, end.x - cp.x)
        } else {
            endAngle = atan2(end.y - start.y, end.x - start.x)
        }
        drawArrowhead(at: end, angle: endAngle, length: headLength, style: style, color: color, lw: lw, in: &context)

        if style == .doubleEnded {
            let startAngle: CGFloat = atan2(start.y - end.y, start.x - end.x)
            drawArrowhead(at: start, angle: startAngle, length: headLength, style: style, color: color, lw: lw, in: &context)
        }
    }

    private func drawArrowhead(at tip: CGPoint, angle: CGFloat, length: CGFloat, style: ArrowStyle, color: Color, lw: CGFloat, in context: inout GraphicsContext) {
        let spread: CGFloat = .pi / 6
        let p1 = CGPoint(x: tip.x - length * cos(angle - spread), y: tip.y - length * sin(angle - spread))
        let p2 = CGPoint(x: tip.x - length * cos(angle + spread), y: tip.y - length * sin(angle + spread))

        var head = Path()
        head.move(to: tip)
        head.addLine(to: p1)
        head.addLine(to: p2)
        head.closeSubpath()

        if style == .hollow {
            context.stroke(head, with: .color(color), lineWidth: lw)
        } else {
            context.fill(head, with: .color(color))
        }
    }

    private func curvedControlPoint(from start: CGPoint, to end: CGPoint, style: ArrowStyle, scale: CGFloat) -> CGPoint {
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dist = sqrt(dx * dx + dy * dy)
        let offset = dist * 0.35
        let perpX = -dy / dist * offset
        let perpY = dx / dist * offset
        let sign: CGFloat = style == .curvedRight ? 1 : -1
        return CGPoint(x: mid.x + perpX * sign, y: mid.y + perpY * sign)
    }

    private func drawCounter(_ item: AnnotationItem, in context: inout GraphicsContext, scale: CGFloat, color: Color) {
        let center = scaled(item.startPoint, scale: scale)
        let imageMinDim = min(state.baseImage.size.width, state.baseImage.size.height)
        let baseRadius = max(10, min(18, imageMinDim * 0.02))
        let radius = baseRadius * scale
        let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: circleRect), with: .color(color))

        if let number = item.counterNumber {
            let fontSize = baseRadius * scale
            let text = Text("\(number)")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(.white)
            context.draw(text, at: center)
        }
    }

    // MARK: - Text Overlays

    @ViewBuilder
    private func textOverlay(for item: AnnotationItem) -> some View {
        if let text = item.text {
            let pos = scaled(item.startPoint, scale: scale)
            Text(text)
                .font(.system(size: item.fontSize * scale, weight: .medium))
                .foregroundColor(Color(nsColor: item.color))
                .position(x: pos.x + textWidth(text, fontSize: item.fontSize * scale) / 2,
                          y: pos.y + item.fontSize * scale / 2)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func textEditOverlay(for item: AnnotationItem) -> some View {
        let pos = scaled(item.startPoint, scale: scale)
        TextEditorField(
            text: Binding(
                get: { state.editingText },
                set: { state.editingText = $0 }
            ),
            fontSize: item.fontSize * scale,
            color: item.color,
            onCommit: { commitText() }
        )
        .position(x: pos.x + 60, y: pos.y)
    }

    private func commitText() {
        guard var item = state.activeAnnotation, item.tool == .text else { return }
        item.text = state.editingText
        if !state.editingText.isEmpty {
            state.commitAnnotation(item)
        }
        state.activeAnnotation = nil
        state.editingTextID = nil
        state.editingText = ""
    }

    private func textWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        return (text as NSString).size(withAttributes: attrs).width
    }

    // MARK: - Coordinate helpers

    private func scaled(_ point: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: point.x * scale, y: point.y * scale)
    }

    private func scaledRect(from start: CGPoint, to end: CGPoint, scale: CGFloat) -> CGRect {
        let s = scaled(start, scale: scale)
        let e = scaled(end, scale: scale)
        return CGRect(
            x: min(s.x, e.x),
            y: min(s.y, e.y),
            width: abs(e.x - s.x),
            height: abs(e.y - s.y)
        )
    }
}

// MARK: - Inline Text Editor

struct TextEditorField: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let color: NSColor
    var onCommit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isEditable = true
        field.isBordered = false
        field.drawsBackground = false
        field.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        field.textColor = color
        field.focusRingType = .none
        field.alignment = .left
        field.stringValue = text
        field.delegate = context.coordinator
        field.sizeToFit()
        field.setFrameSize(NSSize(width: max(120, field.frame.width), height: field.frame.height))

        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: TextEditorField
        init(parent: TextEditorField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            }
            return false
        }
    }
}

// MARK: - Mouse Interaction Layer

struct AnnotationInteractionLayer: NSViewRepresentable {
    @ObservedObject var state: AnnotationState
    let viewSize: CGSize
    let imageSize: CGSize
    let scale: CGFloat
    let imageOffset: CGPoint

    func makeNSView(context: Context) -> AnnotationInteractionNSView {
        let view = AnnotationInteractionNSView()
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: AnnotationInteractionNSView, context: Context) {
        context.coordinator.state = state
        context.coordinator.viewSize = viewSize
        context.coordinator.imageSize = imageSize
        context.coordinator.scale = scale
        context.coordinator.imageOffset = imageOffset
        nsView.isHandTool = state.currentTool == .hand
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state, viewSize: viewSize, imageSize: imageSize, scale: scale, imageOffset: imageOffset)
    }

    class Coordinator: NSObject, AnnotationInteractionDelegate {
        var state: AnnotationState
        var viewSize: CGSize
        var imageSize: CGSize
        var scale: CGFloat
        var imageOffset: CGPoint

        private enum HandDragMode {
            case wholeItem
            case startEndpoint
            case endEndpoint
        }

        private var movingAnnotationID: UUID?
        private var moveStartImagePoint: CGPoint = .zero
        private var moveOriginalItem: AnnotationItem?
        private var handDragMode: HandDragMode = .wholeItem

        init(state: AnnotationState, viewSize: CGSize, imageSize: CGSize, scale: CGFloat, imageOffset: CGPoint) {
            self.state = state
            self.viewSize = viewSize
            self.imageSize = imageSize
            self.scale = scale
            self.imageOffset = imageOffset
        }

        private func imagePoint(from viewPoint: CGPoint) -> CGPoint {
            CGPoint(
                x: (viewPoint.x - imageOffset.x) / scale,
                y: (viewPoint.y - imageOffset.y) / scale
            )
        }

        // MARK: - Hit Testing

        private func hitTest(at imgPt: CGPoint) -> AnnotationItem? {
            for item in state.annotations.reversed() {
                if itemContains(item, point: imgPt) {
                    return item
                }
            }
            return nil
        }

        private func itemContains(_ item: AnnotationItem, point: CGPoint) -> Bool {
            let tolerance: CGFloat = max(item.lineWidth * 2, 8)

            switch item.tool {
            case .rectangle, .roundedRectangle, .filledRectangle, .blur:
                let rect = normalizedRect(from: item.startPoint, to: item.endPoint)
                let expanded = rect.insetBy(dx: -tolerance, dy: -tolerance)
                return expanded.contains(point)

            case .circle:
                let rect = normalizedRect(from: item.startPoint, to: item.endPoint)
                let expanded = rect.insetBy(dx: -tolerance, dy: -tolerance)
                return expanded.contains(point)

            case .line, .arrow:
                return distanceToSegment(point: point, a: item.startPoint, b: item.endPoint) < tolerance

            case .text:
                let textRect = CGRect(x: item.startPoint.x, y: item.startPoint.y - item.fontSize,
                                      width: max(80, CGFloat((item.text?.count ?? 5)) * item.fontSize * 0.6),
                                      height: item.fontSize * 1.4)
                return textRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)

            case .counter:
                let imgMinDim = min(imageSize.width, imageSize.height)
                let radius = max(10, min(18, imgMinDim * 0.02)) + tolerance
                let dx = point.x - item.startPoint.x
                let dy = point.y - item.startPoint.y
                return (dx * dx + dy * dy) <= radius * radius

            case .pencil, .highlight:
                let hitTolerance = item.tool == .highlight ? max(tolerance, 12) : tolerance
                for p in item.points {
                    let dx = point.x - p.x
                    let dy = point.y - p.y
                    if (dx * dx + dy * dy) <= hitTolerance * hitTolerance { return true }
                }
                if item.points.count >= 2 {
                    for i in 0..<(item.points.count - 1) {
                        if distanceToSegment(point: point, a: item.points[i], b: item.points[i + 1]) < hitTolerance {
                            return true
                        }
                    }
                }
                return false

            case .crop, .hand:
                return false
            }
        }

        private func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
            CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                   width: abs(b.x - a.x), height: abs(b.y - a.y))
        }

        private func distanceToSegment(point: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
            let dx = b.x - a.x
            let dy = b.y - a.y
            let lenSq = dx * dx + dy * dy
            guard lenSq > 0 else {
                let px = point.x - a.x, py = point.y - a.y
                return sqrt(px * px + py * py)
            }
            let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lenSq))
            let projX = a.x + t * dx
            let projY = a.y + t * dy
            let px = point.x - projX, py = point.y - projY
            return sqrt(px * px + py * py)
        }

        private func hitTestEndpoint(at imgPt: CGPoint) -> (AnnotationItem, HandDragMode)? {
            let handleRadius: CGFloat = 12
            for item in state.annotations.reversed() where item.tool == .arrow || item.tool == .line {
                let dStart = hypot(imgPt.x - item.startPoint.x, imgPt.y - item.startPoint.y)
                if dStart <= handleRadius { return (item, .startEndpoint) }
                let dEnd = hypot(imgPt.x - item.endPoint.x, imgPt.y - item.endPoint.y)
                if dEnd <= handleRadius { return (item, .endEndpoint) }
            }
            return nil
        }

        private func offsetItem(_ item: AnnotationItem, by delta: CGSize) -> AnnotationItem {
            var moved = item
            moved.startPoint = CGPoint(x: item.startPoint.x + delta.width, y: item.startPoint.y + delta.height)
            moved.endPoint = CGPoint(x: item.endPoint.x + delta.width, y: item.endPoint.y + delta.height)
            if !item.points.isEmpty {
                moved.points = item.points.map {
                    CGPoint(x: $0.x + delta.width, y: $0.y + delta.height)
                }
            }
            return moved
        }

        // MARK: - Mouse Events

        func mouseDown(at point: CGPoint) {
            let imgPt = imagePoint(from: point)
            let tool = state.currentTool

            guard tool != .crop else { return }

            // Hand tool: check endpoint handles first, then whole-item hit test
            if tool == .hand {
                if let (item, mode) = hitTestEndpoint(at: imgPt) {
                    movingAnnotationID = item.id
                    moveStartImagePoint = imgPt
                    moveOriginalItem = item
                    handDragMode = mode
                    state.saveUndoState()
                } else if let hit = hitTest(at: imgPt) {
                    movingAnnotationID = hit.id
                    moveStartImagePoint = imgPt
                    moveOriginalItem = hit
                    handDragMode = .wholeItem
                    state.saveUndoState()
                }
                return
            }

            if let active = state.activeAnnotation, active.tool == .text {
                var item = active
                item.text = state.editingText
                if !state.editingText.isEmpty {
                    state.commitAnnotation(item)
                }
                state.activeAnnotation = nil
                state.editingTextID = nil
                state.editingText = ""
            }

            switch tool {
            case .text:
                let item = AnnotationItem(
                    tool: .text,
                    startPoint: imgPt,
                    color: state.currentColor,
                    lineWidth: state.lineWidth,
                    fontSize: state.fontSize
                )
                state.activeAnnotation = item
                state.editingTextID = item.id
                state.editingText = ""

            case .counter:
                let num = state.nextCounter()
                let item = AnnotationItem(
                    tool: .counter,
                    startPoint: imgPt,
                    color: state.currentColor,
                    lineWidth: state.lineWidth,
                    counterNumber: num
                )
                state.commitAnnotation(item)

            case .pencil:
                let item = AnnotationItem(
                    tool: .pencil,
                    startPoint: imgPt,
                    endPoint: imgPt,
                    color: state.currentColor,
                    lineWidth: state.lineWidth,
                    points: [imgPt]
                )
                state.activeAnnotation = item

            case .highlight:
                let item = AnnotationItem(
                    tool: .highlight,
                    startPoint: imgPt,
                    endPoint: imgPt,
                    color: state.currentColor,
                    lineWidth: state.lineWidth,
                    points: [imgPt]
                )
                state.activeAnnotation = item

            default:
                let item = AnnotationItem(
                    tool: tool,
                    startPoint: imgPt,
                    endPoint: imgPt,
                    color: state.currentColor,
                    lineWidth: state.lineWidth,
                    fontSize: state.fontSize,
                    arrowStyle: tool == .arrow ? state.arrowStyle : .filled
                )
                state.activeAnnotation = item
            }
        }

        func mouseDragged(at point: CGPoint) {
            let imgPt = imagePoint(from: point)

            // Hand tool: move whole item or stretch endpoint
            if state.currentTool == .hand, let originalItem = moveOriginalItem, movingAnnotationID != nil {
                let delta = CGSize(
                    width: imgPt.x - moveStartImagePoint.x,
                    height: imgPt.y - moveStartImagePoint.y
                )
                switch handDragMode {
                case .wholeItem:
                    let moved = offsetItem(originalItem, by: delta)
                    state.replaceAnnotation(moved)
                case .startEndpoint:
                    var updated = originalItem
                    updated.startPoint = CGPoint(x: originalItem.startPoint.x + delta.width,
                                                  y: originalItem.startPoint.y + delta.height)
                    state.replaceAnnotation(updated)
                case .endEndpoint:
                    var updated = originalItem
                    updated.endPoint = CGPoint(x: originalItem.endPoint.x + delta.width,
                                                y: originalItem.endPoint.y + delta.height)
                    state.replaceAnnotation(updated)
                }
                return
            }

            guard var active = state.activeAnnotation else { return }

            if active.tool == .pencil || active.tool == .highlight {
                active.points.append(imgPt)
                active.endPoint = imgPt
            } else {
                active.endPoint = imgPt
            }
            state.activeAnnotation = active
        }

        func mouseUp(at point: CGPoint) {
            if state.currentTool == .hand {
                movingAnnotationID = nil
                moveOriginalItem = nil
                return
            }

            guard var active = state.activeAnnotation else { return }
            let imgPt = imagePoint(from: point)

            if active.tool == .text {
                return
            }

            if active.tool == .pencil || active.tool == .highlight {
                active.points.append(imgPt)
                active.endPoint = imgPt
            } else {
                active.endPoint = imgPt
            }

            let minDist: CGFloat = 2
            let dx = abs(active.endPoint.x - active.startPoint.x)
            let dy = abs(active.endPoint.y - active.startPoint.y)
            if active.tool != .pencil && active.tool != .highlight && dx < minDist && dy < minDist {
                state.activeAnnotation = nil
                return
            }

            state.commitAnnotation(active)
            state.activeAnnotation = nil
        }
    }
}

protocol AnnotationInteractionDelegate: AnyObject {
    func mouseDown(at point: CGPoint)
    func mouseDragged(at point: CGPoint)
    func mouseUp(at point: CGPoint)
}

class AnnotationInteractionNSView: NSView {
    weak var delegate: AnnotationInteractionDelegate?
    private var isDragging = false

    var isHandTool: Bool = false {
        didSet {
            if isHandTool != oldValue {
                window?.invalidateCursorRects(for: self)
            }
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        if isHandTool {
            addCursorRect(bounds, cursor: .openHand)
        } else {
            addCursorRect(bounds, cursor: .crosshair)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if isHandTool {
            isDragging = true
            NSCursor.closedHand.set()
        }
        let loc = convert(event.locationInWindow, from: nil)
        let flipped = CGPoint(x: loc.x, y: bounds.height - loc.y)
        delegate?.mouseDown(at: flipped)
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let flipped = CGPoint(x: loc.x, y: bounds.height - loc.y)
        delegate?.mouseDragged(at: flipped)
    }

    override func mouseUp(with event: NSEvent) {
        if isHandTool && isDragging {
            isDragging = false
            NSCursor.openHand.set()
        }
        let loc = convert(event.locationInWindow, from: nil)
        let flipped = CGPoint(x: loc.x, y: bounds.height - loc.y)
        delegate?.mouseUp(at: flipped)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "z" {
            if event.modifierFlags.contains(.shift) {
                NotificationCenter.default.post(name: .annotationRedo, object: nil)
            } else {
                NotificationCenter.default.post(name: .annotationUndo, object: nil)
            }
            return
        }
        super.keyDown(with: event)
    }
}

extension Notification.Name {
    static let annotationUndo = Notification.Name("annotationUndo")
    static let annotationRedo = Notification.Name("annotationRedo")
}
