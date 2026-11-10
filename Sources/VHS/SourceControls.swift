import AppKit
import SwiftUI
import VHSSignal
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
                Text("Source").font(KitType.section)
                Picker("Source", selection: Binding(get: { model.scene.source }, set: { model.send(.selectSource($0)) })) {
                    ForEach(SourceRegistry.sources) { source in
                        Text(source.title).tag(source.id)
                    }
                }.labelsHidden().accessibilityLabel("Source").help(model.scene.source.definition.summary).frame(minHeight: Metric.control)
            }
            .gridProbe("source-picker", area: "inspector")
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
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
        case let .number(range), let .integer(range):
            NumericParameter(parameter.title, unit: parameter.unit, value: model.scene.number(parameter.id), range: range,
                             defaultValue: defaultNumber, digits: parameter.fractionDigits, integer: isInteger,
                             change: { send(.number($0)) }, beginEdit: model.beginEdit, endEdit: model.endEdit)
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
    private var defaultNumber: Double { if case let .number(v) = parameter.defaultValue { v } else { 0 } }
    private var isInteger: Bool { if case .integer = parameter.kind { true } else { false } }
}
