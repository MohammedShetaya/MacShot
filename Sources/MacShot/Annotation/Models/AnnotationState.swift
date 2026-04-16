import AppKit
import Combine

final class AnnotationState: ObservableObject {
    @Published var baseImage: NSImage
    @Published var currentTool: AnnotationTool = .hand
    @Published var annotations: [AnnotationItem] = []
    @Published var currentColor: NSColor = .systemRed
    @Published var lineWidth: CGFloat = 3
    @Published var fontSize: CGFloat = 18
    @Published var nextCounterNumber: Int = 1
    @Published var arrowStyle: ArrowStyle = .filled

    @Published var activeAnnotation: AnnotationItem?
    @Published var editingTextID: UUID?
    @Published var editingText: String = ""

    @Published var cropRect: CGRect?
    @Published var isCropping: Bool = false
    @Published var cropModified: Bool = false

    // MARK: - Padding / Background Decoration
    // These don't become annotation items; they are applied as a render-time
    // frame around the screenshot (in the canvas and in the final export).
    @Published var paddingEnabled: Bool = false
    @Published var paddingSize: CGFloat = 64
    @Published var paddingStyle: PaddingStyle = .autoGradient
    @Published var paddingGradientStart: NSColor = NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.32, alpha: 1.0)
    @Published var paddingGradientEnd: NSColor = NSColor(calibratedRed: 0.42, green: 0.18, blue: 0.46, alpha: 1.0)
    @Published var paddingGradientAngle: Double = 135
    @Published var paddingSolidColor: NSColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)
    @Published var paddingCornerRadius: CGFloat = 12
    @Published var paddingShadowEnabled: Bool = true

    private struct Snapshot {
        let baseImage: NSImage
        let annotations: [AnnotationItem]
        let nextCounterNumber: Int
    }

    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []

    init(image: NSImage) {
        self.baseImage = image
    }

    // MARK: - Undo / Redo

    private func currentSnapshot() -> Snapshot {
        Snapshot(
            baseImage: baseImage,
            annotations: annotations,
            nextCounterNumber: nextCounterNumber
        )
    }

    private func restore(_ snapshot: Snapshot) {
        baseImage = snapshot.baseImage
        annotations = snapshot.annotations
        nextCounterNumber = snapshot.nextCounterNumber
    }

    func saveUndoState() {
        undoStack.append(currentSnapshot())
        redoStack.removeAll()
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot())
        restore(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot())
        restore(next)
    }

    // MARK: - Annotation Management

    func commitAnnotation(_ item: AnnotationItem) {
        saveUndoState()
        annotations.append(item)
    }

    func removeAnnotation(id: UUID) {
        saveUndoState()
        annotations.removeAll { $0.id == id }
    }

    func replaceAnnotation(_ updated: AnnotationItem) {
        guard let idx = annotations.firstIndex(where: { $0.id == updated.id }) else { return }
        annotations[idx] = updated
    }

    func replaceAnnotationWithUndo(_ updated: AnnotationItem) {
        saveUndoState()
        replaceAnnotation(updated)
    }

    func nextCounter() -> Int {
        let n = nextCounterNumber
        nextCounterNumber += 1
        return n
    }

    // MARK: - Crop

    func applyCrop() {
        guard let rect = cropRect else { return }
        let imageSize = baseImage.size

        let cropOrigin = CGPoint(
            x: max(0, rect.origin.x),
            y: max(0, rect.origin.y)
        )
        let cropSize = CGSize(
            width: min(rect.width, imageSize.width - cropOrigin.x),
            height: min(rect.height, imageSize.height - cropOrigin.y)
        )
        let clampedRect = CGRect(origin: cropOrigin, size: cropSize)
        guard clampedRect.width > 1, clampedRect.height > 1 else { return }

        let flippedRect = CGRect(
            x: clampedRect.origin.x,
            y: imageSize.height - clampedRect.origin.y - clampedRect.height,
            width: clampedRect.width,
            height: clampedRect.height
        )

        guard let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let cropped = cgImage.cropping(to: flippedRect) else { return }

        let newImage = NSImage(cgImage: cropped, size: NSSize(width: clampedRect.width, height: clampedRect.height))

        // Snapshot pre-crop state so Cmd-Z restores the original image + annotations.
        saveUndoState()

        baseImage = newImage
        cropRect = nil
        isCropping = false
        cropModified = false
        annotations.removeAll()
    }

    // MARK: - Final Render

    func renderFinalImage() -> NSImage {
        let annotated = AnnotationRenderer.renderFinal(annotations: annotations, onto: baseImage)
        guard paddingEnabled, paddingSize > 0 else { return annotated }
        return PaddingRenderer.render(annotated, config: PaddingRenderer.config(from: self))
    }
}
