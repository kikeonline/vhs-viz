import SwiftUI
import VHSSignal
import VHSCore

struct EffectChain: View {
    let model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("Effects").font(KitType.section)
                Text("\(model.scene.effects.count)/\(EffectRegistry.maximumEffects)").font(KitType.meta).foregroundStyle(Ink.secondary)
                Spacer()
                Button("Source") { model.selectEffect(nil) }
                    .help("Show source controls")
                Menu("Add Effect", systemImage: KitIcon.add.rawValue) {
                    ForEach(EffectRegistry.definitions) { definition in
                        Button(definition.title) { model.addEffect(definition.id) }
                    }
                }
                .disabled(model.scene.effects.count >= EffectRegistry.maximumEffects)
                .help(model.scene.effects.count >= EffectRegistry.maximumEffects ? "The chain supports up to 16 effects" : "Add a visual effect to the end of the chain")
            }
            .gridProbe("effect-chain-header", area: "effect-chain")
            if model.scene.effects.isEmpty {
                Text("No effects yet")
                    .font(KitType.body).foregroundStyle(Ink.secondary)
                    .gridProbe("effect-chain-empty", area: "effect-chain")
            } else {
                List(selection: Binding(get: { model.selectedEffectID }, set: { model.selectEffect($0) })) {
                    ForEach(Array(model.scene.effects.enumerated()), id: \.element.id) { index, effect in
                        HStack(spacing: Space.sm) {
                            Text("\(index+1)").font(KitType.value).strikethrough(effect.bypassed).frame(width: Space.xxl)
                            Text(effect.kind.definition.title)
                                .lineLimit(1).help(effect.kind.definition.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if effect.bypassed { Text("Bypassed").font(KitType.meta).foregroundStyle(Ink.secondary) }
                            Toggle("Bypass", isOn: Binding(get: { effect.bypassed }, set: { model.send(.bypassEffect(effect.id, $0)) }))
                                .labelsHidden().toggleStyle(.checkbox)
                                .accessibilityLabel("Bypass \(effect.kind.definition.title) \(index+1)")
                                .help("Skip this effect and keep its settings")
                            Button("Move Up", systemImage: KitIcon.up.rawValue) { model.moveEffect(effect.id, by: -1) }
                                .disabled(index == 0).help("Apply this effect earlier in the chain")
                            Button("Move Down", systemImage: KitIcon.down.rawValue) { model.moveEffect(effect.id, by: 1) }
                                .disabled(index == model.scene.effects.count-1).help("Apply this effect later in the chain")
                        }
                        .signalRow(selected: model.selectedEffectID == effect.id)
                        .listRowBackground(model.selectedEffectID == effect.id ? Ink.selection : Ink.surface)
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
                .listStyle(.inset).scrollContentBackground(.hidden).background(Ink.surface)
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
                Text(effect.kind.definition.title).font(KitType.section).help(effect.kind.definition.summary)
                Spacer()
                Button("Source") { model.selectEffect(nil) }.help("Return to source controls")
            }.gridProbe("effect-inspector-title", area: "effect-inspector")
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
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
    private var defaultNumber: Double { if case let .number(v) = parameter.defaultValue { v } else { 0 } }
    var body: some View {
        switch parameter.kind {
        case let .number(range):
            NumericParameter(parameter.title, unit: parameter.unit, value: effect.number(parameter.id), range: range,
                             defaultValue: defaultNumber, change: { send(.number($0)) }, beginEdit: model.beginEdit, endEdit: model.endEdit)
        case .color:
            ColorPicker(parameter.title, selection: Binding(get: { SceneColorBridge.native(effect.color(parameter.id)) }, set: {
                if let color = SceneColorBridge.scene($0) { send(.color(color)) }
            }), supportsOpacity: false).accessibilityLabel(parameter.title)
        default: EmptyView()
        }
    }
}
