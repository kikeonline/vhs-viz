import AppKit
import SwiftUI
import VHSCore

enum SceneColorBridge {
    private static let linearSpace = NSColorSpace(cgColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!)!
    static func native(_ value: SceneColor) -> Color { Color(.sRGBLinear, red:value.red, green:value.green, blue:value.blue) }
    static func scene(_ color: Color) -> SceneColor? {
        guard let c = NSColor(color).usingColorSpace(linearSpace) else { return nil }
        return .init(red:Double(c.redComponent),green:Double(c.greenComponent),blue:Double(c.blueComponent))
    }
}

/// The registry is the single source of control names, types, ranges and defaults.
struct SourceControls: View {
    let model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Source").font(.headline)
                Picker("Source", selection: Binding(get: { model.scene.source }, set: { model.send(.selectSource($0)) })) {
                    ForEach(SourceRegistry.sources) { source in
                        Text(source.title).tag(source.id)
                    }
                }.labelsHidden().accessibilityLabel("Source")
            }
            .gridProbe("source-picker", area: "inspector")
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    Text(model.scene.source.definition.summary).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .gridProbe("source-description", area: "source-parameters")
                    ForEach(model.scene.source.definition.parameters) { parameter in
                        GeneratedParameter(model: model, parameter: parameter)
                            .disabled(parameter.enabledWhen?.matches(model.scene) == false)
                            .gridProbe(parameter.id.rawValue, area: "source-parameters")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .gridArea("source-parameters", inset: 0)
                .padding(.trailing, Space.sm)
                .padding(.bottom, Space.sm)
            }
            .scrollBounceBehavior(.basedOnSize)
            .id(model.scene.source)
            .gridProbe("parameter-scroll", area: "inspector")
        }
        .gridArea("inspector", inset: 0)
    }
}

private struct GeneratedParameter: View {
    let model: AppModel
    let parameter: ParameterDefinition
    private func send(_ value: ParameterValue) { model.send(.setValue(parameter.id, value)) }
    var body: some View {
        switch parameter.kind {
        case let .number(range):
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(parameter.title)
                    Spacer()
                    Text(model.scene.number(parameter.id), format: .number.precision(.fractionLength(parameter.fractionDigits)))
                        .monospacedDigit().foregroundStyle(.secondary)
                    if !parameter.unit.isEmpty { Text(parameter.unit).foregroundStyle(.secondary) }
                }
                .gridProbe(parameter.id.rawValue + "-label", area: parameter.id.rawValue + "-control")
                Slider(value: Binding(get: { model.scene.number(parameter.id) }, set: { send(.number($0)) }), in: range,
                       onEditingChanged: { if $0 { model.beginEdit() } else { model.endEdit() } })
                    .accessibilityLabel(parameter.title)
                    .accessibilityValue(model.scene.number(parameter.id).formatted(.number.precision(.fractionLength(parameter.fractionDigits))))
                    .help(numberHelp)
                    .gridProbe(parameter.id.rawValue + "-slider", area: parameter.id.rawValue + "-control")
            }.gridArea(parameter.id.rawValue + "-control", inset: 0)
        case .integer:
            LabeledContent(parameter.title) {
                TextField(parameter.title, value: Binding(get: { Int(model.scene.number(parameter.id)) }, set: { send(.number(Double($0))) }),
                          format: .number.grouping(.never))
                    .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                    .accessibilityLabel(parameter.title)
            }
        case .color:
            ColorPicker(parameter.title, selection: Binding(get: {
                SceneColorBridge.native(model.scene.tint(parameter.id))
            }, set: { color in
                if let c = SceneColorBridge.scene(color) { send(.color(c)) }
            }), supportsOpacity: false)
            .accessibilityLabel(parameter.title)
        case let .choice(options):
            Picker(parameter.title, selection: Binding(get: { model.scene.choice(parameter.id) }, set: { send(.choice($0)) })) {
                ForEach(options, id: \.id) { option in Text(option.title).tag(option.id) }
            }.accessibilityLabel(parameter.title)
        case .toggle:
            Toggle(parameter.title, isOn: Binding(get: { model.scene.enabled(parameter.id) }, set: { send(.toggle($0)) }))
                .accessibilityLabel(parameter.title)
        }
    }
    private var numberHelp: String {
        switch parameter.id {
        case .solidRed: "Set the linear red component from 0 to 1"
        case .solidGreen: "Set the linear green component from 0 to 1"
        case .solidBlue: "Set the linear blue component from 0 to 1"
        default: "Adjust \(parameter.title.lowercased())\(parameter.unit.isEmpty ? "" : " in " + parameter.unit)"
        }
    }
}
