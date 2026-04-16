import AppKit
import UniformTypeIdentifiers

final class ScreenshotDragSource: NSObject, NSDraggingSource {
    private let image: NSImage
    private var temporaryFileURL: URL?

    init(image: NSImage) {
        self.image = image
        super.init()
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? .copy : .generic
    }

    func beginDrag(from view: NSView, event: NSEvent) {
        let pasteboardItem = NSPasteboardItem()

        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            pasteboardItem.setData(pngData, forType: .png)

            let tempURL = createTemporaryFile(pngData: pngData)
            if let tempURL {
                pasteboardItem.setString(tempURL.absoluteString, forType: .fileURL)
                temporaryFileURL = tempURL
            }
        }

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)

        let thumbnailSize = NSSize(width: 80, height: 80)
        let scaledImage = createThumbnail(from: image, fitting: thumbnailSize)
        let draggingFrame = NSRect(
            origin: view.convert(event.locationInWindow, from: nil),
            size: thumbnailSize
        )
        draggingItem.setDraggingFrame(draggingFrame, contents: scaledImage)

        view.beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        cleanupTemporaryFile()
    }

    private func createTemporaryFile(pngData: Data) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let timestamp = formatter.string(from: Date())
        let filename = "MacShot \(timestamp).png"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try pngData.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    private func cleanupTemporaryFile() {
        guard let url = temporaryFileURL else { return }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFileURL = nil
    }

    private func createThumbnail(from image: NSImage, fitting targetSize: NSSize) -> NSImage {
        let aspectRatio = image.size.width / image.size.height
        var newSize = targetSize
        if aspectRatio > 1 {
            newSize.height = targetSize.width / aspectRatio
        } else {
            newSize.width = targetSize.height * aspectRatio
        }

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        thumbnail.unlockFocus()
        return thumbnail
    }
}
