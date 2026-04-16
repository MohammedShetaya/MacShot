import AppKit
import CoreImage

enum AnnotationRenderer {

    static func render(annotations: [AnnotationItem], onto image: NSImage) -> NSImage {
        let size = image.size
        let result = NSImage(size: size)
        result.lockFocus()

        image.draw(in: NSRect(origin: .zero, size: size))

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            result.unlockFocus()
            return image
        }

        // Annotation coordinates use top-left origin (from SwiftUI canvas),
        // but NSImage.lockFocus() gives a bottom-left origin context.
        // Flip the context so annotation drawing matches stored coordinates.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)

        for item in annotations {
            drawAnnotation(item, in: ctx, imageSize: size)
        }

        ctx.restoreGState()
        result.unlockFocus()
        return result
    }

    static func drawAnnotation(_ item: AnnotationItem, in ctx: CGContext, imageSize: CGSize) {
        ctx.saveGState()
        defer { ctx.restoreGState() }

        let color = item.color.cgColor
        ctx.setStrokeColor(color)
        ctx.setFillColor(color)
        ctx.setLineWidth(item.lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        switch item.tool {
        case .rectangle:
            drawRectangle(item, in: ctx)
        case .roundedRectangle:
            drawRoundedRectangle(item, in: ctx)
        case .filledRectangle:
            drawFilledRectangle(item, in: ctx)
        case .circle:
            drawCircle(item, in: ctx)
        case .line:
            drawLine(item, in: ctx)
        case .arrow:
            drawArrow(item, in: ctx)
        case .text:
            drawText(item, in: ctx)
        case .blur:
            break // blur handled separately via compositing
        case .counter:
            drawCounter(item, in: ctx, imageSize: imageSize)
        case .highlight:
            drawHighlight(item, in: ctx)
        case .pencil:
            drawPencil(item, in: ctx)
        case .crop, .hand, .padding:
            break
        }
    }

    // MARK: - Rectangle

    private static func drawRectangle(_ item: AnnotationItem, in ctx: CGContext) {
        let rect = normalizedRect(from: item.startPoint, to: item.endPoint)
        ctx.stroke(rect)
    }

    // MARK: - Rounded Rectangle

    private static func drawRoundedRectangle(_ item: AnnotationItem, in ctx: CGContext) {
        let rect = normalizedRect(from: item.startPoint, to: item.endPoint)
        let path = CGPath(roundedRect: rect, cornerWidth: item.cornerRadius, cornerHeight: item.cornerRadius, transform: nil)
        ctx.addPath(path)
        ctx.strokePath()
    }

    // MARK: - Filled Rectangle

    private static func drawFilledRectangle(_ item: AnnotationItem, in ctx: CGContext) {
        let rect = normalizedRect(from: item.startPoint, to: item.endPoint)
        ctx.fill(rect)
    }

    // MARK: - Circle / Ellipse

    private static func drawCircle(_ item: AnnotationItem, in ctx: CGContext) {
        let rect = normalizedRect(from: item.startPoint, to: item.endPoint)
        ctx.strokeEllipse(in: rect)
    }

    // MARK: - Line

    private static func drawLine(_ item: AnnotationItem, in ctx: CGContext) {
        ctx.move(to: item.startPoint)
        ctx.addLine(to: item.endPoint)
        ctx.strokePath()
    }

    // MARK: - Arrow

    private static func drawArrow(_ item: AnnotationItem, in ctx: CGContext) {
        let start = item.startPoint
        let end = item.endPoint
        let style = item.arrowStyle

        // Draw shaft
        ctx.beginPath()
        switch style {
        case .curvedRight, .curvedLeft:
            let cp = curvedControlPoint(from: start, to: end, style: style)
            ctx.move(to: start)
            ctx.addQuadCurve(to: end, control: cp)
        default:
            ctx.move(to: start)
            ctx.addLine(to: end)
        }
        ctx.strokePath()

        // End arrowhead
        let headLength: CGFloat = max(12, item.lineWidth * 4)
        let endAngle: CGFloat
        if style == .curvedRight || style == .curvedLeft {
            let cp = curvedControlPoint(from: start, to: end, style: style)
            endAngle = atan2(end.y - cp.y, end.x - cp.x)
        } else {
            endAngle = atan2(end.y - start.y, end.x - start.x)
        }
        drawArrowhead(in: ctx, at: end, angle: endAngle, length: headLength, style: style, lineWidth: item.lineWidth)

        // Start arrowhead for double-ended
        if style == .doubleEnded {
            let startAngle = atan2(start.y - end.y, start.x - end.x)
            drawArrowhead(in: ctx, at: start, angle: startAngle, length: headLength, style: style, lineWidth: item.lineWidth)
        }
    }

    private static func drawArrowhead(in ctx: CGContext, at tip: CGPoint, angle: CGFloat, length: CGFloat, style: ArrowStyle, lineWidth: CGFloat) {
        let spread: CGFloat = .pi / 6
        let p1 = CGPoint(x: tip.x - length * cos(angle - spread), y: tip.y - length * sin(angle - spread))
        let p2 = CGPoint(x: tip.x - length * cos(angle + spread), y: tip.y - length * sin(angle + spread))

        ctx.beginPath()
        ctx.move(to: tip)
        ctx.addLine(to: p1)
        ctx.addLine(to: p2)
        ctx.closePath()

        if style == .hollow {
            ctx.setLineWidth(lineWidth)
            ctx.strokePath()
        } else {
            ctx.fillPath()
        }
    }

    private static func curvedControlPoint(from start: CGPoint, to end: CGPoint, style: ArrowStyle) -> CGPoint {
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0 else { return mid }
        let offset = dist * 0.35
        let perpX = -dy / dist * offset
        let perpY = dx / dist * offset
        let sign: CGFloat = style == .curvedRight ? 1 : -1
        return CGPoint(x: mid.x + perpX * sign, y: mid.y + perpY * sign)
    }

    // MARK: - Text

    private static func drawText(_ item: AnnotationItem, in ctx: CGContext) {
        guard let text = item.text, !text.isEmpty else { return }

        let font = NSFont.systemFont(ofSize: item.fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: item.color
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attrString.size()

        // The parent context is flipped (top-left origin). NSAttributedString.draw(at:)
        // expects an unflipped context, so we locally unflip around the text position.
        ctx.saveGState()
        ctx.translateBy(x: item.startPoint.x, y: item.startPoint.y + textSize.height)
        ctx.scaleBy(x: 1, y: -1)
        attrString.draw(at: .zero)
        ctx.restoreGState()
    }

    // MARK: - Counter

    private static func drawCounter(_ item: AnnotationItem, in ctx: CGContext, imageSize: CGSize) {
        let minDim = min(imageSize.width, imageSize.height)
        let radius = max(10, min(18, minDim * 0.02))
        let center = item.startPoint

        ctx.setFillColor(item.color.cgColor)
        ctx.fillEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        if let number = item.counterNumber {
            let text = "\(number)"
            let font = NSFont.systemFont(ofSize: radius, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white
            ]
            let attrStr = NSAttributedString(string: text, attributes: attributes)
            let textSize = attrStr.size()

            ctx.saveGState()
            ctx.translateBy(x: center.x - textSize.width / 2, y: center.y + textSize.height / 2)
            ctx.scaleBy(x: 1, y: -1)
            attrStr.draw(at: .zero)
            ctx.restoreGState()
        }
    }

    // MARK: - Highlight

    private static func drawHighlight(_ item: AnnotationItem, in ctx: CGContext) {
        guard item.points.count >= 2 else { return }

        let highlightColor = item.color.withAlphaComponent(0.35).cgColor
        ctx.setStrokeColor(highlightColor)
        ctx.setLineWidth(20)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setBlendMode(.normal)

        ctx.beginPath()
        ctx.move(to: item.points[0])
        for i in 1..<item.points.count {
            ctx.addLine(to: item.points[i])
        }
        ctx.strokePath()
    }

    // MARK: - Pencil / Freehand

    private static func drawPencil(_ item: AnnotationItem, in ctx: CGContext) {
        guard item.points.count >= 2 else { return }

        ctx.beginPath()
        ctx.move(to: item.points[0])
        for i in 1..<item.points.count {
            ctx.addLine(to: item.points[i])
        }
        ctx.strokePath()
    }

    // MARK: - Blur Region

    static func applyBlurRegions(to image: NSImage, annotations: [AnnotationItem]) -> NSImage {
        let blurItems = annotations.filter { $0.tool == .blur }
        guard !blurItems.isEmpty else { return image }

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              var ciImage = CIImage(bitmapImageRep: bitmap) else { return image }

        let context = CIContext()
        let imageSize = image.size

        for item in blurItems {
            let rect = normalizedRect(from: item.startPoint, to: item.endPoint)
            guard rect.width > 1, rect.height > 1 else { continue }

            let flippedRect = CGRect(
                x: rect.origin.x,
                y: imageSize.height - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            )

            guard let pixellateFilter = CIFilter(name: "CIPixellate") else { continue }
            pixellateFilter.setValue(ciImage, forKey: kCIInputImageKey)
            pixellateFilter.setValue(max(rect.width, rect.height) / 12, forKey: kCIInputScaleKey)
            pixellateFilter.setValue(CIVector(cgPoint: CGPoint(x: flippedRect.midX, y: flippedRect.midY)), forKey: kCIInputCenterKey)

            guard let pixellated = pixellateFilter.outputImage else { continue }

            let cropVector = CIVector(
                x: flippedRect.origin.x,
                y: flippedRect.origin.y,
                z: flippedRect.width,
                w: flippedRect.height
            )
            guard let cropFilter = CIFilter(name: "CICrop") else { continue }
            cropFilter.setValue(pixellated, forKey: kCIInputImageKey)
            cropFilter.setValue(cropVector, forKey: "inputRectangle")

            guard let croppedPixellated = cropFilter.outputImage else { continue }

            guard let compositeFilter = CIFilter(name: "CISourceOverCompositing") else { continue }
            compositeFilter.setValue(croppedPixellated, forKey: kCIInputImageKey)
            compositeFilter.setValue(ciImage, forKey: kCIInputBackgroundImageKey)

            guard let composited = compositeFilter.outputImage else { continue }
            ciImage = composited
        }

        let extent = ciImage.extent
        guard let cgResult = context.createCGImage(ciImage, from: extent) else { return image }

        let result = NSImage(cgImage: cgResult, size: imageSize)
        return result
    }

    // MARK: - Full Render Pipeline (blur + annotations)

    static func renderFinal(annotations: [AnnotationItem], onto image: NSImage) -> NSImage {
        let blurred = applyBlurRegions(to: image, annotations: annotations)
        let nonBlurAnnotations = annotations.filter { $0.tool != .blur && $0.tool != .crop && $0.tool != .hand }
        return render(annotations: nonBlurAnnotations, onto: blurred)
    }

    // MARK: - Helpers

    private static func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
}
