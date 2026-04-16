import SwiftUI

struct CropOverlayView: View {
    @ObservedObject var state: AnnotationState
    let imageSize: CGSize
    let viewSize: CGSize

    private let handleSize: CGFloat = 10
    @State private var dragEdge: CropEdge?
    @State private var dragStart: CGPoint = .zero
    @State private var initialRect: CGRect = .zero

    private var scale: CGFloat {
        let sx = viewSize.width / imageSize.width
        let sy = viewSize.height / imageSize.height
        return min(sx, sy)
    }

    private var offset: CGPoint {
        let scaledW = imageSize.width * scale
        let scaledH = imageSize.height * scale
        return CGPoint(
            x: (viewSize.width - scaledW) / 2,
            y: (viewSize.height - scaledH) / 2
        )
    }

    private var cropViewRect: CGRect {
        guard let crop = state.cropRect else {
            return CGRect(origin: offset, size: CGSize(width: imageSize.width * scale, height: imageSize.height * scale))
        }
        return CGRect(
            x: crop.origin.x * scale + offset.x,
            y: crop.origin.y * scale + offset.y,
            width: crop.width * scale,
            height: crop.height * scale
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                dimOverlay(in: geo.size)
                cropBorder
                cropHandles
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)
        }
    }

    // MARK: - Dim Overlay

    @ViewBuilder
    private func dimOverlay(in size: CGSize) -> some View {
        let rect = cropViewRect
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRect(rect)
        }
        .fill(style: FillStyle(eoFill: true))
        .foregroundColor(Color.black.opacity(0.5))
        .allowsHitTesting(false)
    }

    // MARK: - Border

    private var cropBorder: some View {
        let rect = cropViewRect
        return Rectangle()
            .stroke(Color.white, lineWidth: 1.5)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }

    // MARK: - Handles

    private var cropHandles: some View {
        let rect = cropViewRect
        let corners: [(CGPoint, CropEdge)] = [
            (CGPoint(x: rect.minX, y: rect.minY), .topLeft),
            (CGPoint(x: rect.maxX, y: rect.minY), .topRight),
            (CGPoint(x: rect.minX, y: rect.maxY), .bottomLeft),
            (CGPoint(x: rect.maxX, y: rect.maxY), .bottomRight),
        ]
        let edges: [(CGPoint, CropEdge)] = [
            (CGPoint(x: rect.midX, y: rect.minY), .top),
            (CGPoint(x: rect.midX, y: rect.maxY), .bottom),
            (CGPoint(x: rect.minX, y: rect.midY), .left),
            (CGPoint(x: rect.maxX, y: rect.midY), .right),
        ]

        return ZStack {
            ForEach(corners + edges, id: \.1) { pos, edge in
                handleView(at: pos, edge: edge)
            }
        }
    }

    private func handleView(at position: CGPoint, edge: CropEdge) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            .position(position)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragEdge == nil {
                            dragEdge = edge
                            dragStart = value.startLocation
                            initialRect = cropViewRect
                        }
                        updateCrop(edge: edge, translation: value.translation)
                    }
                    .onEnded { _ in
                        dragEdge = nil
                    }
            )
    }

    // MARK: - Move (interior drag)

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragEdge == nil {
                    let start = value.startLocation
                    let rect = cropViewRect
                    if rect.contains(start) {
                        if initialRect == .zero { initialRect = rect }
                        dragEdge = .move
                        dragStart = start
                        initialRect = rect
                    }
                }
                if dragEdge == .move {
                    updateCrop(edge: .move, translation: value.translation)
                }
            }
            .onEnded { _ in
                dragEdge = nil
                initialRect = .zero
            }
    }

    // MARK: - Update Crop

    private func updateCrop(edge: CropEdge, translation: CGSize) {
        var rect = initialRect
        let imageArea = CGRect(
            x: offset.x,
            y: offset.y,
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        switch edge {
        case .topLeft:
            rect.origin.x += translation.width
            rect.origin.y += translation.height
            rect.size.width -= translation.width
            rect.size.height -= translation.height
        case .topRight:
            rect.origin.y += translation.height
            rect.size.width += translation.width
            rect.size.height -= translation.height
        case .bottomLeft:
            rect.origin.x += translation.width
            rect.size.width -= translation.width
            rect.size.height += translation.height
        case .bottomRight:
            rect.size.width += translation.width
            rect.size.height += translation.height
        case .top:
            rect.origin.y += translation.height
            rect.size.height -= translation.height
        case .bottom:
            rect.size.height += translation.height
        case .left:
            rect.origin.x += translation.width
            rect.size.width -= translation.width
        case .right:
            rect.size.width += translation.width
        case .move:
            rect.origin.x += translation.width
            rect.origin.y += translation.height
        }

        rect = constrainRect(rect, within: imageArea)

        let imgRect = CGRect(
            x: (rect.origin.x - offset.x) / scale,
            y: (rect.origin.y - offset.y) / scale,
            width: rect.width / scale,
            height: rect.height / scale
        )
        state.cropRect = imgRect
        state.cropModified = true
    }

    private func constrainRect(_ rect: CGRect, within bounds: CGRect) -> CGRect {
        var r = rect
        r.size.width = max(20, r.size.width)
        r.size.height = max(20, r.size.height)
        r.origin.x = max(bounds.minX, min(r.origin.x, bounds.maxX - r.size.width))
        r.origin.y = max(bounds.minY, min(r.origin.y, bounds.maxY - r.size.height))
        r.size.width = min(r.size.width, bounds.maxX - r.origin.x)
        r.size.height = min(r.size.height, bounds.maxY - r.origin.y)
        return r
    }
}

enum CropEdge: Hashable {
    case topLeft, topRight, bottomLeft, bottomRight
    case top, bottom, left, right
    case move
}
