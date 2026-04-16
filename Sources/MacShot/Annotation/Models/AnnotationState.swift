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

    private var undoStack: [[AnnotationItem]] = []
    private var redoStack: [[AnnotationItem]] = []

    init(image: NSImage) {
        self.baseImage = image
    }

    // MARK: - Undo / Redo

    func saveUndoState() {
        undoStack.append(annotations)
        redoStack.removeAll()
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previous
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
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
        baseImage = newImage
        cropRect = nil
        isCropping = false
        cropModified = false
        annotations.removeAll()
        undoStack.removeAll()
        redoStack.removeAll()
    }

    // MARK: - Final Render

    func renderFinalImage() -> NSImage {
        AnnotationRenderer.renderFinal(annotations: annotations, onto: baseImage)
    }
}
