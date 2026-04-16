import SwiftUI
import AppKit

struct AnnotationToolbar: View {
    @ObservedObject var state: AnnotationState
    var onDone: () -> Void

    @State private var hoveredTool: AnnotationTool?
    @State private var hoveredArrowStyle: ArrowStyle?
    @State private var hoveredWidth: CGFloat?

    private let toolGroups: [[AnnotationTool]] = [
        [.hand, .crop],
        [.rectangle, .roundedRectangle, .filledRectangle, .circle],
        [.line, .arrow],
        [.text, .blur, .counter, .highlight, .pencil],
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 0) {
                    toolButtons
                    toolbarDivider
                    lineWidthPicker
                    Spacer().frame(width: 6)
                    colorPickerButton
                }
                .padding(.trailing, 70)

                HStack {
                    Spacer()
                    doneButton
                }
            }
            .frame(height: 28)
            .padding(.leading, 76)
            .padding(.trailing, 12)

            if state.currentTool == .arrow {
                arrowStylePicker
                    .padding(.top, 3)
                    .padding(.bottom, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: NSColor(white: 0.15, alpha: 1.0)))
        .animation(.easeInOut(duration: 0.15), value: state.currentTool == .arrow)
    }

    // MARK: - Tool Buttons

    private var toolButtons: some View {
        HStack(spacing: 1) {
            ForEach(toolGroups.indices, id: \.self) { groupIdx in
                if groupIdx > 0 {
                    toolbarDivider
                }
                HStack(spacing: 1) {
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
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 26)
                .foregroundColor(isSelected ? .white : Color(white: isHovered ? 0.8 : 0.55))
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            isSelected
                                ? Color.accentColor
                                : (isHovered ? Color.white.opacity(0.08) : Color.clear)
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
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 24, height: 24)
                        .foregroundColor(isSelected ? .white : Color(white: isHovered ? 0.8 : 0.55))
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(
                                    isSelected
                                        ? Color.accentColor
                                        : (isHovered ? Color.white.opacity(0.08) : Color.clear)
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
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Line Width & Color

    private var lineWidthPicker: some View {
        HStack(spacing: 5) {
            ForEach([2.0, 4.0, 6.0], id: \.self) { width in
                let isSelected = state.lineWidth == CGFloat(width)
                let isHovered = hoveredWidth == CGFloat(width) && !isSelected
                Button {
                    state.lineWidth = CGFloat(width)
                } label: {
                    Circle()
                        .fill(isSelected ? Color.white : Color(white: isHovered ? 0.6 : 0.4))
                        .frame(width: CGFloat(width + 3), height: CGFloat(width + 3))
                        .frame(width: 12, height: 26)
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
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .help("Color")
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button(action: onDone) {
            Text("Done")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(red: 0.0, green: 0.48, blue: 1.0))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 4)
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
        .background(Color(nsColor: NSColor(white: 0.12, alpha: 1.0)))
    }
}
