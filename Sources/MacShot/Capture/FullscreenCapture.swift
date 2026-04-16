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

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? CGMainDisplayID()
    }
}
