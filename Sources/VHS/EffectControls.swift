import SwiftUI
import VHSCore

struct EffectChain: View {
    let model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("Effects").font(.headline)
                Text("\(model.scene.effects.count)/\(EffectRegistry.maximumEffects)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Source") { model.selectEffect(nil) }
                    .help("Show source controls")
                Menu("Add Effect", systemImage: "plus") {
                    ForEach(EffectRegistry.definitions) { definition in
                        Button(definition.title) { model.addEffect(definition.id) }
                    }
                }
                .disabled(model.scene.effects.count >= EffectRegistry.maximumEffects)
                .help("Add a visual effect to the end of the chain")
            }
            .gridProbe("effect-chain-header", area: "effect-chain")
            if model.scene.effects.isEmpty {
                Text("Add an effect to change the source.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .gridProbe("effect-chain-empty", area: "effect-chain")
            } else {
                List(selection: Binding(get: { model.selectedEffectID }, set: { model.selectEffect($0) })) {
                    ForEach(Array(model.scene.effects.enumerated()), id: \.element.id) { index, effect in
                        HStack(spacing: Space.sm) {
                            Text("\(index+1). \(effect.kind.definition.title)")
                                .lineLimit(1).help(effect.kind.definition.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Toggle("Bypass", isOn: Binding(get: { effect.bypassed }, set: { model.send(.bypassEffect(effect.id, $0)) }))
                                .labelsHidden().toggleStyle(.checkbox)
                                .accessibilityLabel("Bypass \(effect.kind.definition.title) \(index+1)")
                                .help("Skip this effect and keep its settings")
                            Button("Move Up", systemImage: "chevron.up") { model.moveEffect(effect.id, by: -1) }
                                .disabled(index == 0).help("Apply this effect earlier in the chain")
                            Button("Move Down", systemImage: "chevron.down") { model.moveEffect(effect.id, by: 1) }
                                .disabled(index == model.scene.effects.count-1).help("Apply this effect later in the chain")
                        }
                        .labelStyle(.iconOnly)
                        .tag(effect.id)
                        .contextMenu {
                            Button("Edit Effect") { model.selectEffect(effect.id) }
                            Button(effect.bypassed ? "Enable Effect" : "Bypass Effect") { model.send(.bypassEffect(effect.id, !effect.bypassed)) }
                            Button("Move Up") { model.moveEffect(effect.id, by: -1) }.disabled(index == 0)
                            Button("Move Down") { model.moveEffect(effect.id, by: 1) }.disabled(index == model.scene.effects.count-1)
                            Button("Remove Effect") { model.removeEffect(effect.id) }
                        }
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: Layout.effectListMinHeight)
                .accessibilityLabel("Ordered effects")
                .gridProbe("effect-chain-list", area: "effect-chain")
            }
        }
        .gridArea("effect-chain", inset: 0)
        .disabled(model.files.blocksSceneEditing)
    }
}

struct EffectControls: View {
    let model: AppModel
    let effect: EffectInstance
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            HStack {
                Text(effect.kind.definition.title).font(.headline)
                Spacer()
                Button("Source") { model.selectEffect(nil) }.help("Return to source controls")
            }.gridProbe("effect-inspector-title", area: "effect-inspector")
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    Text(effect.kind.definition.summary).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .gridProbe("effect-description", area: "effect-parameters")
                    Toggle("Bypass", isOn: Binding(get: { effect.bypassed }, set: { model.send(.bypassEffect(effect.id, $0)) }))
                        .help("Skip this effect and keep its settings")
                        .gridProbe("effect-bypass", area: "effect-parameters")
                    ForEach(effect.kind.definition.parameters) { parameter in
                        EffectParameterControl(model: model, effect: effect, parameter: parameter)
                            .gridProbe("effect-" + parameter.id, area: "effect-parameters")
                    }
                    Button("Remove Effect", role: .destructive) { model.removeEffect(effect.id) }
                        .help("Remove this effect from the chain; Undo restores it")
                        .gridProbe("effect-remove", area: "effect-parameters")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .gridArea("effect-parameters", inset: 0)
                .padding(.trailing, Space.sm).padding(.bottom, Space.sm)
            }
            .scrollBounceBehavior(.basedOnSize)
            .id(effect.id)
            .gridProbe("effect-scroll", area: "effect-inspector")
        }
        .gridArea("effect-inspector", inset: 0)
    }
}
private struct EffectParameterControl: View {
    let model: AppModel
    let effect: EffectInstance
    let parameter: EffectParameter
    private func send(_ value: ParameterValue) { model.send(.setEffectValue(effect.id, parameter.id, value)) }
    var body: some View {
        switch parameter.kind {
        case let .number(range):
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(parameter.title)
                    Spacer()
                    Text(effect.number(parameter.id), format: .number.precision(.fractionLength(2)))
                        .monospacedDigit().foregroundStyle(.secondary)
                    if !parameter.unit.isEmpty { Text(parameter.unit).foregroundStyle(.secondary) }
                }
                .gridProbe("effect-\(parameter.id)-label", area: "effect-\(parameter.id)-control")
                Slider(value: Binding(get: { effect.number(parameter.id) }, set: { send(.number($0)) }), in: range,
                       onEditingChanged: { if $0 { model.beginEdit() } else { model.endEdit() } })
                    .accessibilityLabel(parameter.title)
                    .accessibilityValue(effect.number(parameter.id).formatted(.number.precision(.fractionLength(2))))
                    .help("Adjust \(parameter.title.lowercased())\(parameter.unit.isEmpty ? "" : " in " + parameter.unit)")
                    .gridProbe("effect-\(parameter.id)-slider", area: "effect-\(parameter.id)-control")
            }
            .gridArea("effect-\(parameter.id)-control", inset: 0)
        case .color:
            ColorPicker(parameter.title, selection: Binding(get: { SceneColorBridge.native(effect.color(parameter.id)) }, set: {
                if let color = SceneColorBridge.scene($0) { send(.color(color)) }
            }), supportsOpacity: false).accessibilityLabel(parameter.title)
        default: EmptyView()
        }
    }
}
