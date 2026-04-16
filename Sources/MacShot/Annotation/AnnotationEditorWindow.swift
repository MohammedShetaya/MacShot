import AppKit
import SwiftUI

final class AnnotationEditorWindow: NSWindow {
    private let annotationState: AnnotationState
    private var undoObserver: NSObjectProtocol?
    private var redoObserver: NSObjectProtocol?

    init(image: NSImage) {
        self.annotationState = AnnotationState(image: image)

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let maxWidth = screenFrame.width * 0.85
        let maxHeight = screenFrame.height * 0.85
        let toolbarWidth: CGFloat = 650
        let minHeight: CGFloat = 300

        let imgW = image.size.width
        let imgH = image.size.height
        let toolbarHeight: CGFloat = 42
        let bottomBarHeight: CGFloat = 40
        let chromeHeight = toolbarHeight + bottomBarHeight

        let fitScale = min(maxWidth / imgW, (maxHeight - chromeHeight) / imgH, 1.0)
        let scaledImageWidth = imgW * fitScale
        let effectiveMinWidth = max(toolbarWidth, scaledImageWidth)
        let windowWidth = effectiveMinWidth
        let windowHeight = max(minHeight, imgH * fitScale + chromeHeight)

        let windowRect = NSRect(
            x: screenFrame.midX - windowWidth / 2,
            y: screenFrame.midY - windowHeight / 2,
            width: windowWidth,
            height: windowHeight
        )

        super.init(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        appearance = NSAppearance(named: .darkAqua)
        minSize = NSSize(width: effectiveMinWidth, height: minHeight)
        isReleasedWhenClosed = false

        let rootView = AnnotationEditorContentView(
            state: annotationState,
            onDone: { [weak self] in self?.finishEditing() },
            onSave: { [weak self] in self?.saveImage() },
            onCopy: { [weak self] in self?.copyToClipboard() },
            onPin: { [weak self] in self?.pinImage() }
        )

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        contentView?.addSubview(hostingView)

        undoObserver = NotificationCenter.default.addObserver(
            forName: .annotationUndo, object: nil, queue: .main
        ) { [weak self] _ in self?.annotationState.undo() }

        redoObserver = NotificationCenter.default.addObserver(
            forName: .annotationRedo, object: nil, queue: .main
        ) { [weak self] _ in self?.annotationState.redo() }
    }

    deinit {
        if let obs = undoObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = redoObserver { NotificationCenter.default.removeObserver(obs) }
    }

    // MARK: - Actions

    private func finishEditing() {
        let finalImage = renderOutput()
        saveToDefaultLocation(finalImage)
        close()
    }

    private func saveImage() {
        let finalImage = renderOutput()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        panel.nameFieldStringValue = "MacShot \(formatter.string(from: Date())).png"

        panel.beginSheetModal(for: self) { response in
            guard response == .OK, let url = panel.url else { return }
            self.writePNG(finalImage, to: url)
        }
    }

    private func copyToClipboard() {
        let finalImage = renderOutput()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([finalImage])
    }

    private func pinImage() {
        let finalImage = renderOutput()
        close()
        PinWindowManager.shared.pinImage(finalImage)
    }

    private func renderOutput() -> NSImage {
        AnnotationRenderer.renderFinal(annotations: annotationState.annotations, onto: annotationState.baseImage)
    }

    private func saveToDefaultLocation(_ image: NSImage) {
        let dir = AppState().saveDirectory
        let dirURL = URL(fileURLWithPath: (dir as NSString).expandingTildeInPath)

        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let filename = "MacShot \(formatter.string(from: Date())).png"
        let fileURL = dirURL.appendingPathComponent(filename)

        writePNG(image, to: fileURL)
    }

    private func writePNG(_ image: NSImage, to url: URL) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
        try? pngData.write(to: url)
    }
}

// MARK: - Window Drag Area

private struct WindowDragArea<Content: View>: NSViewRepresentable {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    func makeNSView(context: Context) -> WindowDragNSView {
        let hostingView = NSHostingView(rootView: content())
        let dragView = WindowDragNSView()
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        dragView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: dragView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: dragView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: dragView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: dragView.bottomAnchor),
        ])
        return dragView
    }

    func updateNSView(_ nsView: WindowDragNSView, context: Context) {}
}

private class WindowDragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// MARK: - SwiftUI Content View

private struct AnnotationEditorContentView: View {
    @ObservedObject var state: AnnotationState
    let onDone: () -> Void
    let onSave: () -> Void
    let onCopy: () -> Void
    let onPin: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AnnotationToolbar(state: state, onDone: onDone)

            AnnotationCanvas(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: NSColor(white: 0.18, alpha: 1.0)))
                .clipped()
                .environment(\.colorScheme, .light)

            AnnotationBottomBar(
                state: state,
                onSave: onSave,
                onCopy: onCopy,
                onPin: onPin
            )
        }
        .ignoresSafeArea(edges: .top)
    }
}
