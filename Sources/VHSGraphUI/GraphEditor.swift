import AppKit
import SwiftUI
import VHSCore

/// The same document editor is embedded by standalone and the native VST3 probe.
public struct GraphEditor: View {
    let graph: ShaderGraph
    let layout: GraphLayout
    let seed: UInt32
    @Bindable var state: GraphEditorState
    let send: (SceneAction) -> Void
    let setLayout: (GraphLayout) -> Void
    let beginEdit: () -> Void
    let endEdit: () -> Void
    public init(graph: ShaderGraph, layout: GraphLayout, seed: UInt32 = 1, state: GraphEditorState,
                send: @escaping (SceneAction) -> Void, setLayout: @escaping (GraphLayout) -> Void,
                beginEdit: @escaping () -> Void, endEdit: @escaping () -> Void) {
        self.graph = graph; self.layout = layout; self.seed = seed; self.state = state; self.send = send; self.setLayout = setLayout
        self.beginEdit = beginEdit; self.endEdit = endEdit
    }
    public var body: some View {
        HStack(alignment:.top,spacing:Space.xl) {
            VStack(alignment:.leading,spacing:Space.sm) {
                toolbar.gridProbe("graph-toolbar",area:"graph-workspace")
                if let output = state.pendingOutput, let node = graph.node(output.node) {
                    HStack {
                        Text("Connect \(node.kind.title)’s \(node.kind.outputType.rawValue) output to an input.").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Cancel Connection") { state.pendingOutput = nil }.controlSize(.small)
                    }.gridProbe("graph-pending-connection",area:"graph-workspace")
                }
                if let error = state.error { Text(error).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true).gridProbe("graph-error",area:"graph-workspace") }
                NodeCanvas(graph:graph,layout:layout,state:state,send:send,setLayout:setLayout)
                    .gridProbe("graph-canvas",area:"graph-workspace")
            }
            .frame(maxWidth:.infinity,maxHeight:.infinity)
            .gridArea("graph-workspace",inset:0)
            .gridProbe("graph-main",area:"graph-page",edge:nil)
            Divider()
            GraphInspector(graph:graph,layout:layout,state:state,setLayout:setLayout,send:send,beginEdit:beginEdit,endEdit:endEdit)
                .frame(width:Layout.graphInspectorWidth)
                .gridProbe("graph-inspector",area:"graph-page",edge:nil)
        }
        .gridArea("graph-page",inset:0)
        .onExitCommand { state.pendingOutput = nil; state.showingLibrary = false }
    }
    private var toolbar: some View {
        HStack(spacing:Space.sm) {
            Button("Add Node",systemImage:"plus") { state.showingLibrary.toggle() }
                .help("Search the node library and add a node")
                .popover(isPresented:$state.showingLibrary) {
                    VStack(alignment:.leading,spacing:Space.sm) {
                        TextField("Search nodes",text:$state.search).textFieldStyle(.roundedBorder).accessibilityLabel("Search nodes").gridProbe("library-search",area:"node-library")
                        List(state.library,id:\.self) { kind in Button(kind.title) { state.add(kind,to:graph,send:send) }.buttonStyle(.plain) }.gridProbe("library-list",area:"node-library")
                    }.padding(Space.lg).frame(width:Layout.graphLibraryWidth,height:Layout.graphLibraryHeight).gridArea("node-library",inset:Space.lg)
                }
            Button("Duplicate",systemImage:"plus.square.on.square") { endEdit(); state.duplicate(in:graph,send:send) }
                .labelStyle(.iconOnly).help("Duplicate the selected node and its input connections")
                .disabled(state.selection == nil || graph.node(state.selection!)?.kind == .output)
            Button("Remove",systemImage:"trash") { endEdit(); state.remove(in:graph,send:send) }
                .labelStyle(.iconOnly).help("Remove the selected node; Undo restores it")
                .disabled(state.selection == nil || graph.node(state.selection!)?.kind == .output)
            LabeledContent("Seed") {
                TextField("Seed",value:Binding(get:{seed},set:{send(.setSeed($0))}),format:.number.grouping(.never))
                    .textFieldStyle(.roundedBorder).frame(width:Layout.graphSeedWidth).accessibilityLabel("Graph seed")
            }
            Spacer(minLength:Space.sm)
            Button("Zoom Out",systemImage:"minus.magnifyingglass") { zoom(layout.zoom-0.25) }.labelStyle(.iconOnly).help("Zoom out by 25 percent").disabled(layout.zoom <= 0.25)
            Text(layout.zoom,format:.percent.precision(.fractionLength(0))).font(.caption).monospacedDigit()
            Button("Zoom In",systemImage:"plus.magnifyingglass") { zoom(layout.zoom+0.25) }.labelStyle(.iconOnly).help("Zoom in by 25 percent").disabled(layout.zoom >= 2)
            Menu("Pan") {
                Button("Left") { pan(x:Layout.graphPanStep,y:0) }; Button("Right") { pan(x:-Layout.graphPanStep,y:0) }
                Button("Up") { pan(x:0,y:Layout.graphPanStep) }; Button("Down") { pan(x:0,y:-Layout.graphPanStep) }
                Button("Reset View") { var next = layout; next.pan = .init(); next.zoom = 1; setLayout(next) }
            }.help("Move the canvas without dragging")
        }.controlSize(.small)
    }
    private func zoom(_ value: Double) { var next = layout; next.zoom = min(2,max(0.25,value)); setLayout(next) }
    private func pan(x: Double,y: Double) { var next = layout; next.pan.x += x; next.pan.y += y; setLayout(next) }
}

public enum GraphEditorDiagnostics {
    public static func writeLayout(to path: String, width: Double, height: Double) { GridProbes.shared.write(to:path,window:.init(width:width,height:height)) }
}
