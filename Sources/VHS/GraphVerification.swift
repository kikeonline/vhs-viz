import AppKit
import VHSCore
import VHSGraphUI

enum GraphVerification {
    private static func check(_ condition: Bool,_ message: String) throws {
        guard condition else { throw ProjectVerification.Failure(message:message) }
        Verification.log("PASS \(message)")
    }
    static func example() throws -> ShaderGraph {
        let a = GraphNode(kind:.source(.gradient)), b = GraphNode(kind:.source(.noise)), amount = GraphNode(kind:.scalar), mix = GraphNode(kind:.imageMix), output = GraphNode(kind:.output)
        var graph = ShaderGraph(nodes:[a,b,amount,mix,output],edges:[])
        for (source,port) in [(a,"a"),(b,"b"),(amount,"amount")] { graph = try graph.connecting(.init(source.id),to:.init(mix.id,port)) }
        return try graph.connecting(.init(mix.id),to:.init(output.id,"image"))
    }
    static func run(_ model: AppModel) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VHS-graph-\(UUID())")
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:directory) }
        model.replaceProject(.init()); model.showsGraph = true
        let state = model.graphEditor
        state.search = "mix"; try check(state.library.contains(.imageMix) && !state.library.contains(.uv),"Graph library searches node names")
        state.search = ""
        state.add(.scalar,to:model.scene.graph,send:model.send)
        let added = try require(state.selection)
        try check(model.scene.graph.node(added)?.kind == .scalar,"Add Node selects an independent node")
        model.beginEdit(); model.send(.setNodeValue(added,"value",.number(0.2))); model.send(.setNodeValue(added,"value",.number(0.8))); model.endEdit()
        let edited = model.scene; model.undo(); model.redo()
        try check(model.scene == edited,"Node numeric gesture undoes/redoes as one scene edit")
        state.duplicate(in:model.scene.graph,send:model.send)
        let duplicate = try require(state.selection)
        try check(duplicate != added && model.scene.graph.node(duplicate)?.values == model.scene.graph.node(added)?.values,"Duplicate preserves values with a new node identity")
        state.parameterTargets = [.init(node:duplicate,key:"value")]
        state.remove(in:model.scene.graph,send:model.send)
        try check(state.unavailableTargets(in:model.scene.graph).count == 1,"Deleted parameter targets remain explicitly unavailable")
        model.undo(); try check(state.unavailableTargets(in:model.scene.graph).isEmpty,"Undo restores the exact parameter target")
        let count = model.history.past.count
        var layout = model.graphLayout; layout.pan = .init(x:64,y:128); layout.zoom = 0.75; layout.positions[added.uuidString] = .init(x:240,y:400)
        model.setGraphLayout(layout); state.selection = nil
        try check(model.history.past.count == count && model.graphLayout == layout,"Node placement, pan/zoom and selection do not enter musical undo")
        let graph = try example(); model.send(.setGraph(graph))
        try check(!model.scene.canEditChain,"Branching graph cannot be silently flattened into Chain")
        model.output.show()
        let scene = model.scene
        for _ in 0..<200 {
            try await Task.sleep(for:.milliseconds(20)); model.tick()
            if model.frame.scene == scene { break }
        }
        try check(model.frame.scene == scene && model.errorMessage == nil,"Background graph compilation swaps a matching executable at a frame boundary")
        let output = graph.nodes.first { $0.kind == .output }!
        let lastValid = model.frame.scene
        let lastPixels = try model.renderer!.readPixels(model.frame,width:32,height:32)
        let incomplete = try graph.connecting(nil,to:.init(output.id,"image"))
        model.send(.setGraph(incomplete)); try await Task.sleep(for:.milliseconds(250)); model.tick()
        try check(model.frame.scene == lastValid && model.graphBuildMessage.contains("Connect"),"Incomplete graph names the input and retains the last valid preview/output frame")
        try check(try model.renderer!.readPixels(model.frame,width:32,height:32) == lastPixels,"Last valid graph keeps identical actual GPU output after a failed build")
        model.undo()
        let mix = graph.nodes.first { $0.kind == .imageMix }!
        state.connect(.init(mix.id),to:.init(mix.id,"a"),in:model.scene.graph,send:model.send)
        try check(state.error?.contains("Cycle") == true && model.scene.graph == graph,"Invalid cyclic wiring is rejected with a node-specific error")
        state.error = nil
        let path = directory.appendingPathComponent("Graph.vhsproject")
        try check(await model.files.saveProject(to:path),"Graph project saves topology, values and layout")
        let saved = model.document
        model.replaceProject(.init()); await model.files.openProject(path)
        try check(model.document == saved && !model.isDirty && model.showsGraph,"Open restores branching topology/UUIDs, layout, seed and node mode")
        try check(model.renderer!.resourceMetrics.textures <= 24,"Branching render resources stay within three eight-texture slots")
        model.output.window?.performClose(nil); model.graphEditor.parameterTargets = []; model.replaceProject(.init()); model.showsGraph = false
        Verification.log("PASS shader graph self-test")
    }
    private static func require(_ value: UUID?) throws -> UUID {
        guard let value else { throw ProjectVerification.Failure(message:"Graph selection missing") }; return value
    }
}
