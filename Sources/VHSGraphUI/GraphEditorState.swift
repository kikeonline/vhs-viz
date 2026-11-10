import Foundation
import Observation
import VHSCore

@MainActor @Observable public final class GraphEditorState {
    public var selection: UUID?
    public var pendingOutput: GraphEndpoint?
    public var search = ""
    public var error: String?
    public var showingLibrary = false
    /// Supplied by future mapping/host adapters; unresolved references stay explicit.
    public var parameterTargets: [GraphParameterTarget] = []
    public init() {}
    public func unavailableTargets(in graph: ShaderGraph) -> [GraphParameterTarget] { parameterTargets.filter { $0.definition(in:graph) == nil } }
    public var library: [NodeKind] { NodeKind.library.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) } }
    @discardableResult public func apply(_ graph: ShaderGraph, send: (SceneAction) -> Void) -> Bool {
        do { try GraphValidator.validate(graph,requireComplete:false); error = nil; send(.setGraph(graph)); return true }
        catch { self.error = error.localizedDescription; return false }
    }
    public func add(_ kind: NodeKind, to graph: ShaderGraph, send: (SceneAction) -> Void) {
        let node = GraphNode(kind:kind)
        if apply(graph.adding(node),send:send) { selection = node.id; showingLibrary = false }
    }
    public func duplicate(in graph: ShaderGraph, send: (SceneAction) -> Void) {
        guard let selection, graph.node(selection)?.kind != .output else { return }
        let id = UUID()
        if apply(graph.duplicated(selection,newID:id),send:send) { self.selection = id }
    }
    public func remove(in graph: ShaderGraph, send: (SceneAction) -> Void) {
        guard let selection, graph.node(selection)?.kind != .output else { return }
        if apply(graph.removing(selection),send:send) { self.selection = nil; pendingOutput = nil }
    }
    public func connect(_ from: GraphEndpoint?, to: GraphEndpoint, in graph: ShaderGraph, send: (SceneAction) -> Void) {
        do {
            let next = try graph.connecting(from,to:to)
            if apply(next,send:send) { pendingOutput = nil }
        } catch { self.error = error.localizedDescription }
    }
}
