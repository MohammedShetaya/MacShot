import AppKit
import SwiftUI

final class AnnotationEditorWindow: NSWindow {
    private let annotationState: AnnotationState
    private var undoObserver: NSObjectProtocol?
    private var redoObserver: NSObjectProtocol?

    // Visual padding around the screenshot inside the canvas area so the
    // image doesn't sit flush against the window edges. This also keeps
    // the crop handles at the image corners comfortably away from the
    // toolbar / bottom-bar drag regions.
    static let canvasPadding: CGFloat = 24

    // Unified chrome color used for the toolbar background, bottom bar,
    // and the canvas padding around the image, so the editor reads as one
    // dark frame around a floating screenshot (the image/crop rect sits
    // inside this frame on all four sides).
    static let chromeColor: NSColor = NSColor(white: 0.12, alpha: 1.0)
    // Custom window corner radius. Smaller than the macOS default (~10pt)
    // to give the editor a tighter, sharper look.
    static let windowCornerRadius: CGFloat = 4

    init(image: NSImage, captureType: CaptureType? = nil) {
        self.annotationState = AnnotationState(image: image)

        // Window captures get the framed/padded look by default - matches
        // what users expect from apps like CleanShot X. Other captures
        // opt-in via the Frame tool in the toolbar.
        if captureType == .window {
            annotationState.paddingEnabled = true
        }

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
        let canvasPadding = Self.canvasPadding
        let paddingH = canvasPadding * 2
        let paddingV = canvasPadding * 2

        // Fit the image into the available canvas area (screen minus chrome
        // minus the padding we add around the canvas).
        let fitScale = min(
            (maxWidth - paddingH) / imgW,
            (maxHeight - chromeHeight - paddingV) / imgH,
            1.0
        )
        let scaledImageWidth = imgW * fitScale
        let effectiveMinWidth = max(toolbarWidth, scaledImageWidth + paddingH)
        let windowWidth = effectiveMinWidth
        let windowHeight = max(minHeight, imgH * fitScale + chromeHeight + paddingV)

        let windowRect = NSRect(
            x: screenFrame.midX - windowWidth / 2,
            y: screenFrame.midY - windowHeight / 2,
            width: windowWidth,
            height: windowHeight
        )

        // Borderless style gives us complete control over the window's
        // corner radius (the titled theme-frame otherwise forces a ~10pt
        // rounded mask we can't reliably override). We re-add the
        // traffic-light buttons manually below.
        super.init(
            contentRect: windowRect,
            styleMask: [.borderless, .closable, .resizable, .fullSizeContentView, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
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

        // Use a rounded container as the window's contentView. The system
        // titled-window chrome is made transparent above (backgroundColor =
        // .clear / isOpaque = false), so the only visible corners are the
        // ones we draw here. The SwiftUI hosting view is pinned inside and
        // also layer-backed so it renders correctly into the clipped layer.
        let container = RoundedContainerView(
            cornerRadius: Self.windowCornerRadius,
            fillColor: Self.chromeColor
        )
        container.frame = windowRect
        container.autoresizingMask = [.width, .height]

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = Self.windowCornerRadius
        hostingView.layer?.masksToBounds = true
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.contentView = container

        // Since we use a borderless window, re-add the standard traffic
        // light buttons (close / minimize / zoom) manually so the editor
        // still behaves like a normal macOS window.
        installTrafficLightButtons()

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

    // Borderless windows don't become key/main automatically. We want the
    // editor to accept keyboard focus (for undo/redo shortcuts, etc.).
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Route Cmd-Z / Cmd-Shift-Z at the window level so undo/redo works in
    // every tool mode (including crop, which uses its own SwiftUI gesture
    // layer instead of the AnnotationInteractionNSView that also listens
    // for these keys). performKeyEquivalent is consulted before keyDown
    // propagation, so we can handle it without the system beep.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = event.charactersIgnoringModifiers?.lowercased()
        if mods == .command, chars == "z" {
            annotationState.undo()
            return true
        }
        if mods == [.command, .shift], chars == "z" {
            annotationState.redo()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Create and place standard macOS traffic-light buttons on a borderless
    /// window. AppKit will wire up close / minimize / zoom behavior via the
    /// buttons' default target-actions.
    private func installTrafficLightButtons() {
        guard let contentView = contentView else { return }

        let styleMask: NSWindow.StyleMask = [
            .titled, .closable, .miniaturizable, .resizable,
        ]

        let buttons: [NSButton] = [
            NSWindow.standardWindowButton(.closeButton, for: styleMask),
            NSWindow.standardWindowButton(.miniaturizeButton, for: styleMask),
            NSWindow.standardWindowButton(.zoomButton, for: styleMask),
        ].compactMap { $0 }

        // Classic macOS layout: 20pt from the left edge, 20pt from the top,
        // 20pt horizontal spacing between button centers.
        let topInset: CGFloat = 14
        let leftInset: CGFloat = 12
        let spacing: CGFloat = 20

        for (idx, button) in buttons.enumerated() {
            button.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(button)
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: leftInset + CGFloat(idx) * spacing
                ),
                button.topAnchor.constraint(
                    equalTo: contentView.topAnchor,
                    constant: topInset
                ),
            ])
        }
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
        let annotated = AnnotationRenderer.renderFinal(
            annotations: annotationState.annotations,
            onto: annotationState.baseImage
        )
        guard annotationState.paddingEnabled, annotationState.paddingSize > 0 else {
            return annotated
        }
        return PaddingRenderer.render(
            annotated,
            config: PaddingRenderer.config(from: annotationState)
        )
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

// MARK: - Window Drag Region

/// A transparent NSViewRepresentable that can be placed in the `.background`
/// of a SwiftUI view to make empty space in that view act as a draggable
/// area for a borderless/custom window. Interactive controls rendered in
/// front (buttons, color pickers, etc.) still receive their own clicks.
struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowDragNSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class WindowDragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// MARK: - Rounded Container

/// A layer-backed NSView used as the window's `contentView` so we can draw
/// our own (sharper) window corner radius. The system's titled-window chrome
/// is made transparent, so the radius applied here becomes the visible window
/// outline.
private final class RoundedContainerView: NSView {
    init(cornerRadius: CGFloat, fillColor: NSColor) {
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.cornerRadius = cornerRadius
        if #available(macOS 13.0, *) {
            layer?.cornerCurve = .continuous
        }
        layer?.masksToBounds = true
        layer?.backgroundColor = fillColor.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // Ensure the corner radius is re-applied across live resize / appearance
    // changes (AppKit occasionally resets layer properties on window chrome
    // swaps like entering/leaving fullscreen).
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layer?.contentsScale = window?.backingScaleFactor ?? 2
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
                .padding(AnnotationEditorWindow.canvasPadding)
                .background(Color(nsColor: AnnotationEditorWindow.chromeColor))
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
