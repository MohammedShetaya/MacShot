import SwiftUI
import AppKit

struct AnnotationToolbar: View {
    @ObservedObject var state: AnnotationState
    var onDone: () -> Void

    @State private var hoveredTool: AnnotationTool?
    @State private var hoveredArrowStyle: ArrowStyle?
    @State private var hoveredWidth: CGFloat?

    // CleanShot X palette
    private static let toolbarBackground = Color(nsColor: AnnotationEditorWindow.chromeColor)
    private static let iconIdle          = Color(white: 0.92)
    private static let iconHover         = Color.white
    private static let iconSelected      = Color.white
    private static let hoverFill         = Color.white.opacity(0.10)
    private static let selectedFill      = Color(red: 0.04, green: 0.52, blue: 1.0) // #0A84FF-ish

    private let toolGroups: [[AnnotationTool]] = [
        [.hand, .crop],
        [.rectangle, .roundedRectangle, .filledRectangle, .circle],
        [.line, .arrow],
        [.text, .blur, .counter, .highlight, .pencil],
        [.padding],
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 10) {
                    toolButtons
                    groupSeparator
                    lineWidthPicker
                    Spacer().frame(width: 2)
                    colorPickerButton
                }
                .padding(.trailing, 70)

                HStack {
                    Spacer()
                    doneButton
                }
            }
            .frame(height: 32)
            .padding(.leading, 76)
            .padding(.trailing, 12)

            if state.currentTool == .arrow {
                arrowStylePicker
                    .padding(.top, 3)
                    .padding(.bottom, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if state.currentTool == .padding {
                PaddingSubBar(state: state)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Self.toolbarBackground
                WindowDragRegion()
            }
        )
        .animation(.easeInOut(duration: 0.15), value: state.currentTool)
    }

    // MARK: - Tool Buttons

    private var toolButtons: some View {
        HStack(spacing: 10) {
            ForEach(toolGroups.indices, id: \.self) { groupIdx in
                HStack(spacing: 2) {
                    ForEach(toolGroups[groupIdx]) { tool in
                        toolButton(for: tool)
                    }
                }
            }
        }
    }

    private func toolButton(for tool: AnnotationTool) -> some View {
        let isSelected = state.currentTool == tool
        let isHovered = hoveredTool == tool && !isSelected
        return Button {
            selectTool(tool)
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 28)
                .foregroundColor(isSelected ? Self.iconSelected : (isHovered ? Self.iconHover : Self.iconIdle))
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            isSelected
                                ? Self.selectedFill
                                : (isHovered ? Self.hoverFill : Color.clear)
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                hoveredTool = hovering ? tool : (hoveredTool == tool ? nil : hoveredTool)
            }
        }
        .help(tool.label)
    }

    private var arrowStylePicker: some View {
        HStack(spacing: 2) {
            ForEach(ArrowStyle.allCases) { style in
                let isSelected = state.arrowStyle == style
                let isHovered = hoveredArrowStyle == style && !isSelected
                Button {
                    state.arrowStyle = style
                } label: {
                    Image(systemName: style.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 26, height: 24)
                        .foregroundColor(isSelected ? Self.iconSelected : (isHovered ? Self.iconHover : Self.iconIdle))
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(
                                    isSelected
                                        ? Self.selectedFill
                                        : (isHovered ? Self.hoverFill : Color.clear)
                                )
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        hoveredArrowStyle = hovering ? style : (hoveredArrowStyle == style ? nil : hoveredArrowStyle)
                    }
                }
                .help(style.label)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Line Width & Color

    private var lineWidthPicker: some View {
        HStack(spacing: 6) {
            ForEach([2.0, 4.0, 6.0], id: \.self) { width in
                let isSelected = state.lineWidth == CGFloat(width)
                let isHovered = hoveredWidth == CGFloat(width) && !isSelected
                Button {
                    state.lineWidth = CGFloat(width)
                } label: {
                    Circle()
                        .fill(isSelected ? Color.white : Color(white: isHovered ? 0.85 : 0.7))
                        .frame(width: CGFloat(width + 3), height: CGFloat(width + 3))
                        .frame(width: 14, height: 28)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        hoveredWidth = hovering ? CGFloat(width) : (hoveredWidth == CGFloat(width) ? nil : hoveredWidth)
                    }
                }
            }
        }
    }

    private var colorPickerButton: some View {
        Button {
            showNSColorPanel()
        } label: {
            Circle()
                .fill(Color(nsColor: state.currentColor))
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .help("Color")
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button(action: onDone) {
            Text("Done")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.95))
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.black.opacity(0.35), lineWidth: 0.5)
                        .blendMode(.plusDarker)
                        .padding(0.5)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var groupSeparator: some View {
        // Visual breathing room between tool groups and the line-width / color
        // section, without a hard divider line. CleanShot uses subtle spacing
        // instead of separator rules.
        Color.clear.frame(width: 2, height: 16)
    }

    private func selectTool(_ tool: AnnotationTool) {
        if state.currentTool == .crop && tool != .crop {
            if state.cropModified, state.cropRect != nil {
                state.applyCrop()
            } else {
                state.cropRect = nil
            }
            state.isCropping = false
            state.cropModified = false
        }

        state.currentTool = tool

        if tool == .crop {
            state.isCropping = true
            state.cropModified = false
            if state.cropRect == nil {
                state.cropRect = CGRect(origin: .zero, size: state.baseImage.size)
            }
        }

        // Selecting the padding tool turns the frame on (toggles back off
        // if it was already enabled and the user taps the tool again).
        if tool == .padding {
            state.paddingEnabled = true
        }
    }

    private func showNSColorPanel() {
        let panel = NSColorPanel.shared
        panel.color = state.currentColor
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.isContinuous = true
        panel.orderFront(nil)

        NSColorPanel.shared.setTarget(ColorPanelTarget.shared)
        NSColorPanel.shared.setAction(#selector(ColorPanelTarget.colorChanged(_:)))
        ColorPanelTarget.shared.state = state
    }
}

private class ColorPanelTarget: NSObject {
    static let shared = ColorPanelTarget()
    weak var state: AnnotationState?

    @objc func colorChanged(_ sender: NSColorPanel) {
        state?.currentColor = sender.color
    }
}

// MARK: - Bottom Bar

struct AnnotationBottomBar: View {
    @ObservedObject var state: AnnotationState
    var onSave: () -> Void
    var onCopy: () -> Void
    var onPin: () -> Void

    var body: some View {
        HStack {
            Button(action: onPin) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .help("Pin to Desktop")

            Spacer()

            Text("Drag to share")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.6))

            Spacer()

            HStack(spacing: 12) {
                Button(action: onSave) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .help("Save")

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .help("Copy to Clipboard")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            ZStack {
                Color(nsColor: AnnotationEditorWindow.chromeColor)
                WindowDragRegion()
            }
        )
    }
}

// MARK: - Padding Sub-Bar

struct PaddingSubBar: View {
    @ObservedObject var state: AnnotationState

    private static let panelFill = Color.white.opacity(0.06)
    private static let iconIdle = Color(white: 0.92)
    private static let iconSelected = Color.white
    private static let selectedFill = Color.white.opacity(0.16)

    var body: some View {
        HStack(spacing: 12) {
            enableToggle

            Divider().frame(height: 18).opacity(0.2)

            sizeGroup

            Divider().frame(height: 18).opacity(0.2)

            styleSegment

            if state.paddingStyle == .customGradient {
                Divider().frame(height: 18).opacity(0.2)
                gradientColorWells
            } else if state.paddingStyle == .solid {
                Divider().frame(height: 18).opacity(0.2)
                solidColorWell
            }

            Divider().frame(height: 18).opacity(0.2)

            shadowToggle
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Self.panelFill)
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Enable

    private var enableToggle: some View {
        Toggle(isOn: $state.paddingEnabled) {
            Text("Frame")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Self.iconIdle)
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .tint(Color(red: 0.04, green: 0.52, blue: 1.0))
    }

    // MARK: - Size

    private var sizeGroup: some View {
        HStack(spacing: 4) {
            Image(systemName: "square.resize")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Self.iconIdle)
            ForEach([("S", 32.0), ("M", 64.0), ("L", 96.0), ("XL", 140.0)], id: \.0) { label, value in
                sizeButton(label: label, value: CGFloat(value))
            }
        }
    }

    private func sizeButton(label: String, value: CGFloat) -> some View {
        let isSelected = abs(state.paddingSize - value) < 0.5
        return Button {
            state.paddingSize = value
            state.paddingEnabled = true
        } label: {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(isSelected ? Self.iconSelected : Self.iconIdle)
                .frame(width: 22, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSelected ? Self.selectedFill : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help("Padding size: \(label)")
    }

    // MARK: - Style

    private var styleSegment: some View {
        HStack(spacing: 2) {
            ForEach(PaddingStyle.allCases) { style in
                styleButton(style)
            }
        }
    }

    private func styleButton(_ style: PaddingStyle) -> some View {
        let isSelected = state.paddingStyle == style
        return Button {
            state.paddingStyle = style
            state.paddingEnabled = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: style.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(style.label)
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundColor(isSelected ? Self.iconSelected : Self.iconIdle)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isSelected ? Self.selectedFill : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(style.label)
    }

    // MARK: - Color Wells

    private var gradientColorWells: some View {
        HStack(spacing: 6) {
            colorWell(
                color: Binding(
                    get: { state.paddingGradientStart },
                    set: { state.paddingGradientStart = $0 }
                ),
                label: "Start"
            )
            colorWell(
                color: Binding(
                    get: { state.paddingGradientEnd },
                    set: { state.paddingGradientEnd = $0 }
                ),
                label: "End"
            )
        }
    }

    private var solidColorWell: some View {
        colorWell(
            color: Binding(
                get: { state.paddingSolidColor },
                set: { state.paddingSolidColor = $0 }
            ),
            label: "Color"
        )
    }

    private func colorWell(color: Binding<NSColor>, label: String) -> some View {
        PaddingColorWell(color: color)
            .frame(width: 20, height: 20)
            .help(label)
    }

    // MARK: - Shadow

    private var shadowToggle: some View {
        Button {
            state.paddingShadowEnabled.toggle()
        } label: {
            Image(systemName: state.paddingShadowEnabled ? "shadow" : "circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(state.paddingShadowEnabled ? Self.iconSelected : Self.iconIdle)
                .frame(width: 22, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(state.paddingShadowEnabled ? Self.selectedFill : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help("Drop shadow")
    }
}

// MARK: - Color Well

/// A compact color swatch that opens the system color panel on click.
/// We avoid the stock `NSColorWell` here because its default chrome
/// doesn't fit the dark compact toolbar.
private struct PaddingColorWell: NSViewRepresentable {
    @Binding var color: NSColor

    func makeNSView(context: Context) -> PaddingColorWellView {
        let view = PaddingColorWellView()
        view.color = color
        view.onColorChanged = { newColor in
            self.color = newColor
        }
        return view
    }

    func updateNSView(_ nsView: PaddingColorWellView, context: Context) {
        nsView.color = color
        nsView.needsDisplay = true
    }
}

final class PaddingColorWellView: NSView {
    var color: NSColor = .white { didSet { needsDisplay = true } }
    var onColorChanged: ((NSColor) -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
        color.setFill()
        circle.fill()

        NSColor.white.withAlphaComponent(0.4).setStroke()
        circle.lineWidth = 1
        circle.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        PaddingColorPanelCoordinator.shared.present(for: self)
    }
}

private final class PaddingColorPanelCoordinator: NSObject {
    static let shared = PaddingColorPanelCoordinator()
    private weak var activeWell: PaddingColorWellView?

    func present(for well: PaddingColorWellView) {
        activeWell = well

        let panel = NSColorPanel.shared
        panel.color = well.color
        panel.isContinuous = true
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.orderFront(nil)
    }

    @objc func colorChanged(_ sender: NSColorPanel) {
        guard let well = activeWell else { return }
        well.color = sender.color
        well.onColorChanged?(sender.color)
    }
}
