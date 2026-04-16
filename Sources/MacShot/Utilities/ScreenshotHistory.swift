import AppKit

final class ScreenshotHistory: ObservableObject {
    static let shared = ScreenshotHistory()

    @Published var items: [ScreenshotHistoryItem] = []

    private let maxItems = 20
    private let fileManager = FileManager.default

    private var storageURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MacShot", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("screenshot_history.json")
    }

    private init() {
        loadFromDisk()
    }

    /// Testable initializer that skips automatic disk loading.
    init(skipLoad: Bool) {
        if !skipLoad {
            loadFromDisk()
        }
    }

    func add(image: NSImage, filePath: URL?, captureType: CaptureType) {
        let thumbnailData = generateThumbnailData(from: image)
        let item = ScreenshotHistoryItem(
            id: UUID(),
            filePath: filePath?.path,
            captureType: captureType.rawValue,
            timestamp: Date(),
            thumbnailData: thumbnailData
        )

        DispatchQueue.main.async {
            self.items.insert(item, at: 0)
            if self.items.count > self.maxItems {
                self.items.removeLast()
            }
            self.saveToDisk()
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.items.removeAll()
            self.saveToDisk()
        }
    }

    func loadFromDisk() {
        guard fileManager.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            items = try JSONDecoder().decode([ScreenshotHistoryItem].self, from: data)
        } catch {
            items = []
        }
    }

    func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Silently fail; non-critical persistence
        }
    }

    private func generateThumbnailData(from image: NSImage) -> Data? {
        let maxDimension: CGFloat = 128
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let thumbnailSize = NSSize(width: size.width * scale, height: size.height * scale)

        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbnailSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()

        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }
}

struct ScreenshotHistoryItem: Identifiable, Codable {
    let id: UUID
    let filePath: String?
    let captureType: String
    let timestamp: Date
    var thumbnailData: Data?
}
