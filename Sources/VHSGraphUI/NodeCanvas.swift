import SwiftUI
import VHSCore

struct NodeCanvas: View {
    let graph: ShaderGraph
    let layout: GraphLayout
    @Bindable var state: GraphEditorState
    let send: (SceneAction) -> Void
    let setLayout: (GraphLayout) -> Void
    @State private var panOffset = CGSize.zero
    private func position(_ id: UUID) -> CGPoint {
        let index = graph.nodes.firstIndex { $0.id == id } ?? 0
        let point = layout.position(id,index:index) // grid: ok lookup of persisted document coordinates, not a view offset
        return .init(x:point.x,y:point.y)
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment:.topLeading) {
                Rectangle().fill(.background)
                    .gesture(DragGesture().onChanged { panOffset = $0.translation }.onEnded { value in
                        var next = layout; next.pan.x += value.translation.width; next.pan.y += value.translation.height
                        setLayout(next); panOffset = .zero
                    })
                ZStack(alignment:.topLeading) {
                    Canvas { context,_ in
                        for edge in graph.edges {
                            guard let target = graph.node(edge.to.node), let port = target.kind.inputs.firstIndex(where: { $0.id == edge.to.port }) else { continue }
                            let a = position(edge.from.node), b = position(edge.to.node)
                            guard let source = graph.node(edge.from.node) else { continue }
                            let start = CGPoint(x:a.x+Layout.graphNodeWidth,y:a.y+NodeCard.height(source)-Layout.graphNodeFooter/2)
                            let end = CGPoint(x:b.x,y:b.y+Layout.graphNodeHeader+CGFloat(port)*Layout.graphPortHeight+Layout.graphPortHeight/2)
                            var path = Path(); path.move(to:start)
                            path.addCurve(to:end,control1:.init(x:start.x+Space.section,y:start.y),control2:.init(x:end.x-Space.section,y:end.y))
                            context.stroke(path,with:.color(.accentColor),lineWidth:2)
                        }
                    }.allowsHitTesting(false)
                    ForEach(graph.nodes) { node in
                        NodeCard(node:node,graph:graph,zoom:layout.zoom,state:state,send:send,onMove: { delta in
                            var next = layout
                            let start = position(node.id)
                            next.positions[node.id.uuidString] = .init(x:start.x+delta.width/layout.zoom,y:start.y+delta.height/layout.zoom)
                            setLayout(next)
                        })
                        .position(x:position(node.id).x+Layout.graphNodeWidth/2,y:position(node.id).y+NodeCard.height(node)/2) // grid: ok document-space node coordinates are user content
                    }
                }
                .scaleEffect(layout.zoom,anchor:.topLeading)
                .offset(x:layout.pan.x+panOffset.width,y:layout.pan.y+panOffset.height) // grid: ok interactive canvas pan is document-space navigation
            }
            .frame(width:geometry.size.width,height:geometry.size.height)
            .clipped()
            .accessibilityLabel("Shader graph canvas; use the inspector for keyboard wiring")
        }
        .overlay(RoundedRectangle(cornerRadius:Layout.previewRadius).stroke(.separator))
    }
}
private struct NodeCard: View {
    let node: GraphNode
    let graph: ShaderGraph
    let zoom: Double
    @Bindable var state: GraphEditorState
    let send: (SceneAction) -> Void
    let onMove: (CGSize) -> Void
    @State private var drag = CGSize.zero
    static func height(_ node: GraphNode) -> CGFloat { Layout.graphNodeHeader+CGFloat(node.kind.inputs.count)*Layout.graphPortHeight+Layout.graphNodeFooter }
    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            Button { state.selection = node.id } label: {
                HStack(spacing:Space.xs) {
                    Text(node.kind.title).font(.headline)
                    Spacer(minLength:0)
                    if node.bypassed { Text("Bypassed").font(.caption).foregroundStyle(.secondary) }
                }.padding(.horizontal,Space.sm)
            }.buttonStyle(.plain).frame(height:Layout.graphNodeHeader)
                .help("Select \(node.kind.title); drag its title to move the node")
                .gesture(DragGesture(minimumDistance:Space.xs,coordinateSpace:.global).onChanged { state.selection = node.id; drag = $0.translation }.onEnded { onMove($0.translation); drag = .zero })
            ForEach(node.kind.inputs) { port in
                Button {
                    state.selection = node.id
                    if let output = state.pendingOutput { state.connect(output,to:.init(node.id,port.id),in:graph,send:send) }
                } label: {
                    HStack(spacing:Space.xs) {
                        Image(systemName:graph.input(node.id,port.id) == nil ? "circle" : "circle.fill")
                        Text(port.title).lineLimit(1)
                        Spacer(minLength:0)
                        Text(port.type.rawValue).foregroundStyle(.secondary)
                    }.font(.caption).padding(.horizontal,Space.sm)
                }.buttonStyle(.plain).frame(height:Layout.graphPortHeight)
                    .accessibilityLabel("\(node.kind.title) input \(port.title), \(port.type.rawValue)")
                    .help("Drop a matching output here, or choose a connection in the inspector")
                    .dropDestination(for:String.self) { items,_ in
                        guard let value = items.first, let id = UUID(uuidString:value) else { return false }
                        state.connect(.init(id),to:.init(node.id,port.id),in:graph,send:send); return state.error == nil
                    }
            }
            if node.kind != .output {
                Button { state.selection = node.id; state.pendingOutput = .init(node.id) } label: {
                    HStack(spacing:Space.xs) { Text(node.kind.outputType.rawValue); Spacer(); Image(systemName:"circle.fill") }
                        .font(.caption).padding(.horizontal,Space.sm)
                }.buttonStyle(.plain).frame(height:Layout.graphNodeFooter)
                    .draggable(node.id.uuidString)
                    .accessibilityLabel("\(node.kind.title) output, \(node.kind.outputType.rawValue)")
                    .help("Drag to a matching input, or click then choose an input")
            } else { Text("Final image").font(.caption).foregroundStyle(.secondary).padding(.horizontal,Space.sm).frame(height:Layout.graphNodeFooter) }
        }
        .frame(width:Layout.graphNodeWidth)
        .background(.background,in:RoundedRectangle(cornerRadius:Layout.previewRadius))
        .overlay(RoundedRectangle(cornerRadius:Layout.previewRadius).stroke(state.selection == node.id ? Color.accentColor : Color(nsColor:.separatorColor),lineWidth:state.selection == node.id ? 2 : 1))
        .offset(x:drag.width/zoom,y:drag.height/zoom) // grid: ok transient node drag preview is document-space content
        .contextMenu {
            Button("Select Node") { state.selection = node.id }
            if node.kind != .output {
                Button("Duplicate Node") { state.selection = node.id; state.duplicate(in:graph,send:send) }
                Button("Remove Node") { state.selection = node.id; state.remove(in:graph,send:send) }
            }
        }
    }
}
