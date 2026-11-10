import AppKit
import SwiftUI
import VHSCore

struct GraphInspector: View {
    let graph: ShaderGraph
    let layout: GraphLayout
    @Bindable var state: GraphEditorState
    let setLayout: (GraphLayout) -> Void
    let send: (SceneAction) -> Void
    let beginEdit: () -> Void
    let endEdit: () -> Void
    var body: some View {
        VStack(alignment:.leading,spacing:Space.lg) {
            Picker("Selected node",selection:$state.selection) {
                Text("Choose a Node").tag(nil as UUID?)
                ForEach(Array(graph.nodes.enumerated()),id:\.element.id) { index,node in
                    Text("\(index+1). \(node.kind.title)").tag(node.id as UUID?)
                }
            }.accessibilityLabel("Selected node").gridProbe("graph-node-picker",area:"node-inspector")
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment:.leading,spacing:Space.lg) {
                    if let id = state.selection, let node = graph.node(id) {
                        Text(node.kind.title).font(.headline).gridProbe("node-title",area:"node-details")
                        if case .effect = node.kind {
                            Toggle("Bypass",isOn:Binding(get:{node.bypassed},set:{ value in
                                _ = state.apply(graph.replacing(.init(id:node.id,kind:node.kind,values:node.values,bypassed:value)),send:send)
                            })).gridProbe("node-bypass",area:"node-details")
                        }
                        if !node.kind.inputs.isEmpty {
                            Text("Connections").font(.headline).gridProbe("node-connections-title",area:"node-details")
                            ForEach(node.kind.inputs) { port in
                                let options = graph.nodes.filter { $0.id != node.id && $0.kind != .output && $0.kind.outputType == port.type }
                                Picker(port.title,selection:Binding(get:{graph.input(node.id,port.id)?.node},set:{ value in
                                    endEdit(); state.connect(value.map { .init($0) },to:.init(node.id,port.id),in:graph,send:send)
                                })) {
                                    Text(port.required ? "Connect \(port.type.rawValue)…" : "Base value").tag(nil as UUID?)
                                    ForEach(options) { option in Text("\(option.kind.title) · \(option.id.uuidString.prefix(4))").tag(option.id as UUID?) }
                                }
                                .help("Choose a matching output; choose the first option to disconnect")
                                .accessibilityLabel("\(node.kind.title) input \(port.title), \(port.type.rawValue)")
                                .gridProbe("node-input-"+port.id,area:"node-details")
                            }
                        }
                        ForEach(node.kind.parameters) { parameter in
                            NodeParameterControl(node:node,parameter:parameter,send:send,beginEdit:beginEdit,endEdit:endEdit)
                                .disabled(graph.input(node.id,parameter.id) != nil)
                                .gridProbe("node-value-"+parameter.id,area:"node-details")
                        }
                        positionControls(node).gridProbe("node-position",area:"node-details")
                        Text("Node ID: \(node.id.uuidString)").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            .fixedSize(horizontal:false,vertical:true).gridProbe("node-identity",area:"node-details")
                    } else {
                        Text("Select a node to edit its values and connections.").foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                            .gridProbe("node-empty",area:"node-details")
                    }
                    ForEach(state.unavailableTargets(in:graph),id:\.self) { target in
                        Label(target.unavailableMessage,systemImage:"exclamationmark.triangle").font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal:false,vertical:true)
                    }
                }
                .frame(maxWidth:.infinity,alignment:.leading)
                .id("node-inspector-top")
                .gridArea("node-details",inset:0)
                .padding(.trailing,Space.sm).padding(.bottom,Space.sm)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of:state.selection) { _,_ in proxy.scrollTo("node-inspector-top",anchor:.top) }
            }
            .gridProbe("node-details-scroll",area:"node-inspector")
        }.gridArea("node-inspector",inset:0)
    }
    private func positionControls(_ node: GraphNode) -> some View {
        VStack(alignment:.leading,spacing:Space.sm) {
            Text("Canvas position").font(.headline)
            ForEach(["X","Y"],id:\.self) { axis in
                LabeledContent("Position \(axis)") {
                    TextField("Position \(axis)",value:Binding(get:{
                        let point = layout.position(node.id,index:graph.nodes.firstIndex(where:{$0.id == node.id}) ?? 0) // grid: ok persisted document-space coordinate lookup
                        return axis == "X" ? point.x : point.y
                    },set:{ value in
                        var next = layout
                        var point = layout.position(node.id,index:graph.nodes.firstIndex(where:{$0.id == node.id}) ?? 0) // grid: ok persisted document-space coordinate lookup
                        if axis == "X" { point.x = value } else { point.y = value }
                        next.positions[node.id.uuidString] = point; setLayout(next)
                    }),format:.number.precision(.fractionLength(0)))
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Node canvas position \(axis)")
                }
            }
        }
    }
}
private struct NodeParameterControl: View {
    let node: GraphNode
    let parameter: EffectParameter
    let send: (SceneAction) -> Void
    let beginEdit: () -> Void
    let endEdit: () -> Void
    private var value: ParameterValue { node.values[parameter.id] ?? parameter.defaultValue }
    private var number: Double { if case let .number(v) = value { v } else { 0 } }
    private func change(_ value: ParameterValue) { send(.setNodeValue(node.id,parameter.id,value)) }
    var body: some View {
        Group {
            switch parameter.kind {
            case let .number(range), let .integer(range):
                VStack(alignment:.leading,spacing:Space.sm) {
                    HStack(alignment:.firstTextBaseline) {
                        Text(parameter.title); Spacer()
                        Text(number,format:.number.precision(.fractionLength(2))).monospacedDigit().foregroundStyle(.secondary)
                        if !parameter.unit.isEmpty { Text(parameter.unit).foregroundStyle(.secondary) }
                    }.gridProbe("node-\(parameter.id)-label",area:"node-\(parameter.id)-control")
                    Slider(value:Binding(get:{number},set:{change(.number($0))}),in:range,onEditingChanged:{ if $0 { beginEdit() } else { endEdit() } })
                        .accessibilityLabel(parameter.title).help("Adjust \(parameter.title.lowercased())")
                        .gridProbe("node-\(parameter.id)-slider",area:"node-\(parameter.id)-control")
                }.gridArea("node-\(parameter.id)-control",inset:0)
            case .color:
                ColorPicker(parameter.title,selection:Binding(get:{
                    if case let .color(c) = value { return Color(.sRGBLinear,red:c.red,green:c.green,blue:c.blue) }
                    return Color(.sRGBLinear,red:0,green:0,blue:0)
                },set:{ color in
                    let space = NSColorSpace(cgColorSpace:CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!)!
                    if let c = NSColor(color).usingColorSpace(space) { change(.color(.init(red:Double(c.redComponent),green:Double(c.greenComponent),blue:Double(c.blueComponent)))) }
                }),supportsOpacity:false)
            case let .choice(options):
                Picker(parameter.title,selection:Binding(get:{ if case let .choice(v) = value { v } else { "" } },set:{change(.choice($0))})) {
                    ForEach(options,id:\.id) { Text($0.title).tag($0.id) }
                }
            case .toggle:
                Toggle(parameter.title,isOn:Binding(get:{if case let .toggle(v) = value {v} else {false}},set:{change(.toggle($0))}))
            }
        }
        .help("\(parameter.title) · stable target \(node.id.uuidString) / \(parameter.id)")
    }
}
