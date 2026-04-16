import AppKit
import CoreImage

/// Produces a framed version of a screenshot: a padded stage with a
/// configurable background (auto-sampled gradient from the image pixels,
/// a custom gradient, or a solid color), an optional drop shadow behind
/// the screenshot, and rounded corners on the image. Used both by the
/// editor canvas (live preview) and the final export pipeline.
enum PaddingRenderer {
    struct Config {
        var size: CGFloat
        var style: PaddingStyle
        var customStart: NSColor
        var customEnd: NSColor
        var solid: NSColor
        var angle: Double
        var cornerRadius: CGFloat
        var shadow: Bool
    }

    static func config(from state: AnnotationState) -> Config {
        Config(
            size: state.paddingSize,
            style: state.paddingStyle,
            customStart: state.paddingGradientStart,
            customEnd: state.paddingGradientEnd,
            solid: state.paddingSolidColor,
            angle: state.paddingGradientAngle,
            cornerRadius: state.paddingCornerRadius,
            shadow: state.paddingShadowEnabled
        )
    }

    /// Render the screenshot framed with the configured padding/background.
    /// Returns a new image sized (image + 2*padding). If padding is 0, the
    /// original image is returned untouched.
    static func render(_ image: NSImage, config: Config) -> NSImage {
        guard config.size > 0 else { return image }

        let pad = config.size
        let size = CGSize(
            width: image.size.width + pad * 2,
            height: image.size.height + pad * 2
        )

        let result = NSImage(size: size)
        result.lockFocus()
        defer { result.unlockFocus() }

        let fullRect = NSRect(origin: .zero, size: size)

        // 1. Background fill
        drawBackground(in: fullRect, config: config, source: image)

        // 2. Screenshot with rounded corners + shadow
        let imageRect = NSRect(x: pad, y: pad, width: image.size.width, height: image.size.height)
        drawImage(image, in: imageRect, config: config)

        return result
    }

    // MARK: - Background

    private static func drawBackground(in rect: NSRect, config: Config, source: NSImage) {
        switch config.style {
        case .autoGradient:
            let (c1, c2) = autoGradientColors(from: source)
            drawGradient(c1: c1, c2: c2, angle: config.angle, in: rect)
        case .customGradient:
            drawGradient(c1: config.customStart, c2: config.customEnd, angle: config.angle, in: rect)
        case .solid:
            config.solid.setFill()
            rect.fill()
        }
    }

    private static func drawGradient(c1: NSColor, c2: NSColor, angle: Double, in rect: NSRect) {
        guard let gradient = NSGradient(colors: [c1, c2]) else { return }
        gradient.draw(in: rect, angle: CGFloat(angle))
    }

    // MARK: - Image

    private static func drawImage(_ image: NSImage, in rect: NSRect, config: Config) {
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.draw(in: rect)
            return
        }

        ctx.saveGState()
        defer { ctx.restoreGState() }

        if config.shadow {
            let shadowColor = NSColor.black.withAlphaComponent(0.45).cgColor
            let shadowOffset = CGSize(width: 0, height: -max(4, config.size * 0.12))
            let shadowBlur = max(12, config.size * 0.5)
            ctx.setShadow(offset: shadowOffset, blur: shadowBlur, color: shadowColor)
        }

        if config.cornerRadius > 0 {
            let path = NSBezierPath(roundedRect: rect, xRadius: config.cornerRadius, yRadius: config.cornerRadius)
            path.addClip()
        }

        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    // MARK: - Auto Gradient

    /// Derives two gradient endpoint colors from the source image by
    /// sampling averaged pixel colors in two diagonally opposite corners
    /// (top-left and bottom-right regions). Colors are lightly saturated
    /// and darkened a touch so the resulting frame looks intentional
    /// rather than washed out.
    static func autoGradientColors(from image: NSImage) -> (NSColor, NSColor) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return (NSColor(calibratedRed: 0.2, green: 0.2, blue: 0.3, alpha: 1.0),
                    NSColor(calibratedRed: 0.4, green: 0.2, blue: 0.5, alpha: 1.0))
        }

        let w = cg.width
        let h = cg.height
        let sampleW = max(1, w / 3)
        let sampleH = max(1, h / 3)

        let topLeft = averageColor(
            cg: cg,
            rect: CGRect(x: 0, y: 0, width: sampleW, height: sampleH)
        )
        let bottomRight = averageColor(
            cg: cg,
            rect: CGRect(x: w - sampleW, y: h - sampleH, width: sampleW, height: sampleH)
        )

        return (enhance(topLeft), enhance(bottomRight))
    }

    /// Draws the given region of a CGImage into a 1x1 bitmap so that the
    /// system averages all pixels into a single value.
    private static func averageColor(cg: CGImage, rect: CGRect) -> NSColor {
        guard let subImage = cg.cropping(to: rect) else {
            return NSColor(calibratedWhite: 0.2, alpha: 1.0)
        }

        var pixel: [UInt8] = [0, 0, 0, 0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return NSColor(calibratedWhite: 0.2, alpha: 1.0)
        }

        context.interpolationQuality = .medium
        context.draw(subImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        let r = CGFloat(pixel[0]) / 255
        let g = CGFloat(pixel[1]) / 255
        let b = CGFloat(pixel[2]) / 255
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
    }

    /// Pushes the sampled color toward a slightly darker, more saturated
    /// hue so the frame doesn't look like a washed-out blur of the source.
    private static func enhance(_ color: NSColor) -> NSColor {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        // Boost saturation a bit, pull brightness down a touch - produces a
        // richer frame while still echoing the source palette.
        let newS = min(1.0, s * 1.25 + 0.08)
        let newB = max(0.1, min(0.55, b * 0.7))
        return NSColor(calibratedHue: h, saturation: newS, brightness: newB, alpha: 1.0)
    }
}
