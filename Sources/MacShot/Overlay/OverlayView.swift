import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct OverlayView: View {
    let image: NSImage
    let captureType: CaptureType
    var appState: AppState?
    var onDismiss: () -> Void

    @State private var feedbackText: String?
    @State private var isHovering = false
    @State private var savedFileURL: URL?

    var body: some View {
        ZStack {
            // Full-bleed screenshot background
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 200, height: 140)
                .clipped()

            // Frosted glass controls overlay (on hover)
            if isHovering {
                glassControls
                    .transition(.opacity)
            }
        }
        .frame(width: 200, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 3)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
            if hovering {
                NotificationCenter.default.post(name: .overlayMouseEntered, object: nil)
            } else {
                NotificationCenter.default.post(name: .overlayMouseExited, object: nil)
            }
        }
    }

    // MARK: - Glass controls overlaid on screenshot

    private var glassControls: some View {
        ZStack {
            // Frosted glass fill
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)

            VStack(spacing: 0) {
                // Top corners: Pin (left), Close (right)
                HStack {
                    cornerIcon(symbol: "pin.fill", tooltip: "Pin") { pinImage() }
                    Spacer()
                    if let feedbackText {
                        Text(feedbackText)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    cornerIcon(symbol: "xmark", tooltip: "Close") { onDismiss() }
                }

                Spacer()

                // Center: Copy and Save pill buttons
                VStack(spacing: 6) {
                    pillButton(title: "Copy") { copyToClipboard() }
                    pillButton(title: "Save") { saveScreenshot() }
                }

                Spacer()

                // Bottom corners: Annotate (left), Drag (center), Finder (right)
                HStack {
                    cornerIcon(symbol: "pencil.tip", tooltip: "Annotate") { openAnnotationEditor() }
                    Spacer()
                    DragSourceView(image: image)
                        .frame(width: 46, height: 14)
                    Spacer()
                    cornerIcon(symbol: "arrow.up.right.square", tooltip: "Finder") { showInFinder() }
                }
            }
            .padding(10)
        }
    }

    // MARK: - Button Styles

    private func pillButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 100, height: 28)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
    }

    private func cornerIcon(symbol: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.15))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    // MARK: - Actions

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        showFeedback("Copied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            onDismiss()
        }
    }

    @discardableResult
    private func saveScreenshot() -> URL? {
        guard let appState else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let timestamp = formatter.string(from: Date())

        let ext: String
        switch appState.imageFormat {
        case .png:  ext = "png"
        case .jpeg: ext = "jpg"
        case .tiff: ext = "tiff"
        }
        let filename = "MacShot \(timestamp)@2x.\(ext)"

        let directoryURL = URL(fileURLWithPath: appState.saveDirectory, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent(filename)

        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else { return nil }

        let imageData: Data?
        switch appState.imageFormat {
        case .png:
            imageData = bitmapRep.representation(using: .png, properties: [:])
        case .jpeg:
            imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: appState.jpegQuality])
        case .tiff:
            imageData = bitmapRep.representation(using: .tiff, properties: [:])
        }

        guard let data = imageData else { return nil }

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try data.write(to: fileURL)
            let item = ScreenshotItem(image: image, timestamp: Date(), filePath: fileURL, captureType: captureType)
            appState.addScreenshot(item)
            savedFileURL = fileURL
            showFeedback("Saved")
            return fileURL
        } catch {
            showFeedback("Error")
            return nil
        }
    }

    private func pinImage() {
        PinWindowManager.shared.pinImage(image)
        onDismiss()
    }

    private func openAnnotationEditor() {
        AnnotationEditorManager.shared.openEditor(with: image)
        onDismiss()
    }

    private func showInFinder() {
        if let existing = savedFileURL, FileManager.default.fileExists(atPath: existing.path) {
            NSWorkspace.shared.activateFileViewerSelecting([existing])
            return
        }
        if let url = saveScreenshot() {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func showFeedback(_ text: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            feedbackText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                feedbackText = nil
            }
        }
    }
}

struct DragSourceView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> DragSourceNSView {
        DragSourceNSView(image: image)
    }

    func updateNSView(_ nsView: DragSourceNSView, context: Context) {}
}

final class DragSourceNSView: NSView {
    private let image: NSImage
    private var dragSource: ScreenshotDragSource?

    init(image: NSImage) {
        self.image = image
        super.init(frame: .zero)
        self.dragSource = ScreenshotDragSource(image: image)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.5),
            .paragraphStyle: paragraphStyle
        ]
        let text = "Drag me"
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {}

    override func mouseDragged(with event: NSEvent) {
        dragSource?.beginDrag(from: self, event: event)
    }
}

extension Notification.Name {
    static let overlayMouseEntered = Notification.Name("overlayMouseEntered")
    static let overlayMouseExited = Notification.Name("overlayMouseExited")
}
