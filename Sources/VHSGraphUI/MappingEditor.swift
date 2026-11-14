import Foundation
import Observation
import SwiftUI
import VHSCore
import VHSSignal

@MainActor @Observable public final class MappingEditorState {
    public var isPresented = false
    public var selected: UUID?
    public private(set) var waiting = false
    public private(set) var candidate: VisualMapping?
    public private(set) var detected = ""
    public var inputAvailable = false
    public var feedback: [GraphParameterTarget: Double] = [:]
    private var armed: VisualMapping?
    public init() {}
    public func cancel() { waiting = false; candidate = nil; armed = nil; detected = "" }
    public func learn(_ mapping: VisualMapping) { cancel(); selected = mapping.id; armed = mapping; waiting = true }
    public func accept(channel: Int, number: Int, note: Bool) {
        guard waiting, let armed, armed.channel == nil || armed.channel == channel,
              (1...16).contains(channel), (0...127).contains(number) else { return }
        candidate = MappingLearn.candidate(armed,channel:channel,number:number,note:note,omni:armed.channel == nil)
        detected = "Channel \(channel) · \(note ? "Note" : "CC") \(number)"
        waiting = false
    }
}

/// Shared native editor. Definitions belong to the caller's document; discovery is transient.
public struct MappingEditor: View {
    let scene: SceneSnapshot
    @Bindable var state: MappingEditorState
    let send: (SceneAction) -> Void
    let host: Bool
    public init(scene: SceneSnapshot, state: MappingEditorState, host: Bool = false, send: @escaping (SceneAction) -> Void) {
        self.scene = scene; self.state = state; self.host = host; self.send = send
    }
    private var targets: [GraphParameterTarget] {
        scene.graph.nodes.flatMap { node in node.kind.parameters.filter { GraphParameterTarget.eligible($0.kind) && scene.graph.input(node.id,$0.id) == nil }.map { .init(node:node.id,key:$0.id) } }
    }
    private func title(_ target: GraphParameterTarget) -> String {
        guard let node = scene.graph.node(target.node), let p = target.definition(in:scene.graph) else { return "Unavailable · \(target.key)" }
        let index = (scene.graph.nodes.firstIndex { $0.id == node.id } ?? 0)+1
        return "\(index). \(node.kind.title) · \(p.title)"
    }
    private func update(_ mapping: VisualMapping) {
        state.cancel()
        send(.setMappings(scene.mappings.map { $0.id == mapping.id ? mapping : $0 }))
    }
    private func binding<T>(_ mapping: VisualMapping, _ key: WritableKeyPath<VisualMapping,T>) -> Binding<T> {
        Binding(get:{ mapping[keyPath:key] },set:{ value in var next = mapping; next[keyPath:key] = value; update(next) })
    }
    public var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:Space.lg) {
                Text("Mappings").font(KitType.section).gridProbe("mapping-title",area:"mappings")
                if scene.mappings.isEmpty {
                    Text("Add a mapping to make this scene respond to audio or MIDI.").font(KitType.body).foregroundStyle(Ink.secondary)
                        .fixedSize(horizontal:false,vertical:true).gridProbe("mapping-empty",area:"mappings")
                } else {
                    Picker("Mapping",selection:$state.selected) {
                        Text("Choose a Mapping").tag(nil as UUID?)
                        ForEach(scene.mappings) { m in Text("\(m.source.title) → \(title(m.target))").tag(m.id as UUID?) }
                    }.gridProbe("mapping-picker",area:"mappings")
                }
                Button("Add Mapping") {
                    guard let target = targets.first else { return }
                    var m = VisualMapping(target:target)
                    if let p = target.definition(in:scene.graph), case let .number(r) = p.kind { m.upper = r.upperBound-r.lowerBound }
                    send(.setMappings(scene.mappings+[m])); state.cancel(); state.selected = m.id
                }.disabled(targets.isEmpty || scene.mappings.count >= 128).gridProbe("mapping-add",area:"mappings")
                if let m = scene.mappings.first(where: { $0.id == state.selected }) {
                    details(m).gridProbe("mapping-details",area:"mappings")
                }
            }.padding(Space.margin).gridArea("mappings")
        }
        .frame(width:Layout.mappingWidth,height:Layout.mappingHeight)
        .signalTheme()
        .onChange(of:state.selected) { _,_ in state.cancel() }
        .onDisappear { state.cancel() }
    }
    @ViewBuilder private func details(_ m: VisualMapping) -> some View {
        let unit = m.target.definition(in:scene.graph)?.unit ?? ""
        VStack(alignment:.leading,spacing:Space.md) {
            Picker("Target",selection:binding(m,\.target)) {
                if !targets.contains(m.target) { Text(title(m.target)).tag(m.target) }
                ForEach(targets,id:\.self) { t in Text(title(t)).tag(t) }
            }
            if m.unavailable(in:scene.graph) {
                Label("Target unavailable or connected. Restore the node or choose a target.",systemImage:KitIcon.warning.rawValue)
                    .font(KitType.meta).foregroundStyle(Ink.secondary).fixedSize(horizontal:false,vertical:true)
            }
            Toggle("Enable Mapping",isOn:binding(m,\.enabled))
            Picker("Input",selection:Binding(get:{m.source},set:{ value in
                var next = m; next.source = value
                if value == .cc && next.number == nil { next.number = 1 }
                update(next)
            })) { ForEach(MappingSource.allCases,id:\.self) { Text($0.title).tag($0).disabled(host && !$0.isMIDI && $0 != .peak) } }
            if host { Text("Host audio: Peak available; RMS, bands and transients unavailable.").font(KitType.meta).foregroundStyle(Ink.secondary).fixedSize(horizontal:false,vertical:true) }
            if m.source.isMIDI {
                Picker("Channel",selection:binding(m,\.channel)) {
                    Text("Omni").tag(nil as Int?)
                    ForEach(1...16,id:\.self) { Text("\($0)").tag($0 as Int?) }
                }
                Picker(m.source == .cc ? "Controller" : "Note",selection:binding(m,\.number)) {
                    if m.source != .cc { Text("Any Note (Highest)").tag(nil as Int?) }
                    ForEach(0...127,id:\.self) { Text("\($0)").tag($0 as Int?) }
                }
            }
            HStack(spacing:Space.sm) {
                Button(state.waiting ? "Relearn" : (m.source.isMIDI ? "Relearn MIDI…" : "Learn MIDI…")) { state.learn(m) }
                if state.waiting || state.candidate != nil { Button("Cancel") { state.cancel() }.keyboardShortcut(.cancelAction) }
            }
            if state.waiting {
                Text(state.inputAvailable ? "Waiting for a CC or note. Move a controller or play a note, then inspect the candidate." : "No MIDI input. Enable a source in Inputs or host monitoring, or assign Input, Channel and Controller/Note manually.")
                    .font(KitType.meta).foregroundStyle(Ink.secondary).fixedSize(horizontal:false,vertical:true)
            }
            if host {
                Text("Host MIDI uses Studio One’s controller assignment bank. Start playback/monitoring before Learn to avoid chased values; inspect the candidate before confirming.")
                    .font(KitType.meta).foregroundStyle(Ink.secondary).fixedSize(horizontal:false,vertical:true)
            }
            if let candidate = state.candidate, candidate.id == m.id {
                Text("Detected: \(state.detected)").font(KitType.label)
                let conflicts = scene.mappings.filter { candidate.conflicts(with:$0) }
                if !conflicts.isEmpty { Text("This input is assigned to \(conflicts.count) other mapping(s).").font(KitType.meta) }
                Button(conflicts.isEmpty ? "Confirm" : "Replace Conflicts") {
                    if let values = MappingLearn.confirm(candidate,in:scene.mappings,replaceConflicts:!conflicts.isEmpty) {
                        send(.setMappings(values)); state.cancel()
                    }
                }.keyboardShortcut(.defaultAction)
            }
            Text("Contribution added to base value (\(unit.isEmpty ? "native units" : unit))").font(KitType.meta).foregroundStyle(Ink.secondary)
            field("Minimum",value:binding(m,\.lower),range: -100_000...100_000)
            field("Maximum",value:binding(m,\.upper),range: -100_000...100_000)
            Toggle("Invert Input",isOn:binding(m,\.inverted))
            field("Curve",value:binding(m,\.curve),range:0.1...8)
            field("Smoothing (seconds)",value:binding(m,\.smoothing),range:0...10)
            Group {
            if let value = state.feedback[m.target] {
                LabeledContent("Effective value",value:value.formatted(.number.precision(.fractionLength(3)))+" "+unit)
                    .font(KitType.value).monospacedDigit()
            } else { Text("No active contribution").font(KitType.meta).foregroundStyle(Ink.secondary) }
            }.frame(minHeight:Metric.control).gridProbe("mapping-feedback",area:"mapping-form")
            Button("Clear Mapping",role:.destructive) { send(.setMappings(scene.mappings.filter { $0.id != m.id })); state.cancel(); state.selected = nil }
                .gridProbe("mapping-clear",area:"mapping-form")
        }.gridArea("mapping-form",inset:0)
    }
    private func field(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        MappingNumberField(title:title,value:value,range:range).gridProbe("mapping-field-"+title,area:"mapping-form")

    }
}

private struct MappingNumberField: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var draft = NumericDraft("")
    @FocusState private var focused: Bool
    private var formatted: String { value.formatted(.number.grouping(.never).precision(.fractionLength(0...6))) }
    var body: some View {
        VStack(alignment:.leading,spacing:Space.xs) {
            LabeledContent(title) {
                TextField(title,text:Binding(get:{ focused || draft.isInvalid ? draft.text : formatted },set:{draft.replace($0)}))
                    .textFieldStyle(.roundedBorder).font(KitType.value).monospacedDigit().focused($focused)
                    .accessibilityLabel(title)
                    .help("Return commits a value from \(range.lowerBound.formatted()) to \(range.upperBound.formatted()); Escape cancels.")
                    .onChange(of:focused) { _,active in if active && !draft.isInvalid { draft.cancel(formatted) } }
                    .onSubmit { if let next = draft.commit(in:range) { value = next; focused = false } }
                    .onExitCommand { draft.cancel(formatted); focused = false }
            }
            if draft.isInvalid {
                Text("Enter a value from \(range.lowerBound.formatted()) to \(range.upperBound.formatted()).")
                    .font(KitType.meta).foregroundStyle(Ink.error).fixedSize(horizontal:false,vertical:true)
            }
        }
    }
}
