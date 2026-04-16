import SwiftUI

struct AnnotateSettingsView: View {
    @AppStorage("annotationColor") private var annotationColorHex = "#FF3B30"
    @AppStorage("annotationLineWidth") private var lineWidth = LineWidthOption.medium.rawValue
    @AppStorage("annotationFontSize") private var fontSize: Double = 16
    @AppStorage("smoothDrawing") private var smoothDrawing = true
    @AppStorage("pixelateIntensity") private var pixelateIntensity: Double = 10
    @AppStorage("counterStartNumber") private var counterStartNumber = 1
    @AppStorage("arrowStyleSetting") private var arrowStyleRaw = "filled"

    @State private var selectedColor: Color = .red

    var body: some View {
        Form {
            Section("Defaults") {
                ColorPicker("Default color", selection: $selectedColor)
                    .onChange(of: selectedColor) { newValue in
                        annotationColorHex = newValue.hexString
                    }

                Picker("Default line width", selection: Binding(
                    get: { LineWidthOption(rawValue: lineWidth) ?? .medium },
                    set: { lineWidth = $0.rawValue }
                )) {
                    ForEach(LineWidthOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Default font size")
                    Spacer()
                    TextField("", value: $fontSize, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                    Text("pt")
                        .foregroundColor(.secondary)
                }
            }

            Section("Drawing") {
                Toggle("Smooth drawing (pencil tool)", isOn: $smoothDrawing)

                HStack {
                    Text("Pixelate intensity")
                    Slider(value: $pixelateIntensity, in: 1...20, step: 1)
                    Text("\(Int(pixelateIntensity))")
                        .monospacedDigit()
                        .frame(width: 24, alignment: .trailing)
                }
            }

            Section("Counter") {
                Stepper("Starting number: \(counterStartNumber)", value: $counterStartNumber, in: 0...99)
            }

            Section("Arrow") {
                Picker("Arrow style", selection: Binding(
                    get: { ArrowStyle(rawValue: arrowStyleRaw) ?? .filled },
                    set: { arrowStyleRaw = $0.rawValue }
                )) {
                    ForEach(ArrowStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            if let color = Color(hex: annotationColorHex) {
                selectedColor = color
            }
        }
    }
}

enum LineWidthOption: String, CaseIterable {
    case thin, medium, thick

    var displayName: String { rawValue.capitalized }

    var value: CGFloat {
        switch self {
        case .thin: return 1.0
        case .medium: return 2.0
        case .thick: return 4.0
        }
    }
}

