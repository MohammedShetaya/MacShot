import AppKit

enum AnnotationTool: String, CaseIterable, Identifiable {
    case hand, crop, rectangle, roundedRectangle, filledRectangle, circle
    case line, arrow, text, blur, counter, highlight, pencil
    case padding

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .hand:              return "cursorarrow"
        case .crop:              return "crop"
        case .rectangle:         return "rectangle"
        case .roundedRectangle:  return "app"
        case .filledRectangle:   return "rectangle.fill"
        case .circle:            return "circle"
        case .line:              return "line.diagonal"
        case .arrow:             return "arrow.up.right"
        case .text:              return "textformat"
        case .blur:              return "square.grid.3x3.fill"
        case .counter:           return "1.circle"
        case .highlight:         return "highlighter"
        case .pencil:            return "pencil.tip"
        case .padding:           return "square.on.square.dashed"
        }
    }

    var label: String {
        switch self {
        case .hand:              return "Move"
        case .crop:              return "Crop"
        case .rectangle:         return "Rectangle"
        case .roundedRectangle:  return "Rounded Rect"
        case .filledRectangle:   return "Filled Rect"
        case .circle:            return "Circle"
        case .line:              return "Line"
        case .arrow:             return "Arrow"
        case .text:              return "Text"
        case .blur:              return "Pixelate"
        case .counter:           return "Counter"
        case .highlight:         return "Highlight"
        case .pencil:            return "Draw"
        case .padding:           return "Background"
        }
    }
}

enum PaddingStyle: String, CaseIterable, Identifiable {
    case autoGradient
    case customGradient
    case solid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .autoGradient:   return "Auto"
        case .customGradient: return "Gradient"
        case .solid:          return "Solid"
        }
    }

    var icon: String {
        switch self {
        case .autoGradient:   return "wand.and.stars"
        case .customGradient: return "circle.lefthalf.filled"
        case .solid:          return "circle.fill"
        }
    }
}

enum ArrowStyle: String, CaseIterable, Identifiable {
    case filled       // solid filled arrowhead (default)
    case hollow       // outlined/stroked arrowhead
    case curvedRight  // shaft bends to the right
    case curvedLeft   // shaft bends to the left
    case doubleEnded  // arrowheads on both ends

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .filled:      return "arrow.up.right"
        case .hollow:      return "arrow.up.forward"
        case .curvedRight: return "arrow.turn.down.right"
        case .curvedLeft:  return "arrow.turn.down.left"
        case .doubleEnded: return "arrow.left.arrow.right"
        }
    }

    var label: String {
        switch self {
        case .filled:      return "Filled"
        case .hollow:      return "Hollow"
        case .curvedRight: return "Curve Right"
        case .curvedLeft:  return "Curve Left"
        case .doubleEnded: return "Double-Ended"
        }
    }
}

struct AnnotationItem: Identifiable {
    let id: UUID
    var tool: AnnotationTool
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
    var text: String?
    var counterNumber: Int?
    var points: [CGPoint]
    var fontSize: CGFloat
    var isFilled: Bool
    var cornerRadius: CGFloat
    var arrowStyle: ArrowStyle

    init(
        id: UUID = UUID(),
        tool: AnnotationTool,
        startPoint: CGPoint = .zero,
        endPoint: CGPoint = .zero,
        color: NSColor = .systemRed,
        lineWidth: CGFloat = 3,
        text: String? = nil,
        counterNumber: Int? = nil,
        points: [CGPoint] = [],
        fontSize: CGFloat = 18,
        isFilled: Bool = false,
        cornerRadius: CGFloat = 12,
        arrowStyle: ArrowStyle = .filled
    ) {
        self.id = id
        self.tool = tool
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.color = color
        self.lineWidth = lineWidth
        self.text = text
        self.counterNumber = counterNumber
        self.points = points
        self.fontSize = fontSize
        self.isFilled = isFilled
        self.cornerRadius = cornerRadius
        self.arrowStyle = arrowStyle
    }
}
