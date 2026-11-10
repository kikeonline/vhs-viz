import Foundation

public struct GraphDiagnostic: Error, LocalizedError, Equatable, Sendable {
    public let node: UUID?
    public let message: String
    public init(_ message: String, node: UUID? = nil) { self.node = node; self.message = message }
    public var errorDescription: String? { node.map { "Node \($0.uuidString.prefix(8)): \(message)" } ?? message }
}
public enum GraphValidator {
    @discardableResult public static func validate(_ graph: ShaderGraph, requireComplete: Bool = true) throws -> [GraphNode] {
        guard graph.version == 1 else { throw GraphDiagnostic("Unsupported graph version \(graph.version).") }
        guard graph.nodes.count <= ShaderGraph.maximumNodes, graph.edges.count <= 256 else { throw GraphDiagnostic("Use at most 64 nodes and 256 connections.") }
        guard Set(graph.nodes.map(\.id)).count == graph.nodes.count else { throw GraphDiagnostic("Node identities must be unique.") }
        guard graph.nodes.filter({ $0.kind == .output }).count == 1 else { throw GraphDiagnostic("Keep exactly one Output node.") }
        let nodes = Dictionary(uniqueKeysWithValues:graph.nodes.map { ($0.id,$0) })
        for node in graph.nodes {
            let parameters = node.kind.parameters
            guard Set(node.values.keys) == Set(parameters.map(\.id)), parameters.allSatisfy({ p in node.values[p.id].map { GraphNode.allows(p,$0) } == true }) else {
                throw GraphDiagnostic("Invalid \(node.kind.title) parameter values. Restore valid keys, types and ranges.",node:node.id)
            }
            if node.bypassed, case .effect = node.kind {} else if node.bypassed { throw GraphDiagnostic("Only effects can be bypassed.",node:node.id) }
        }
        var destinations = Set<GraphEndpoint>()
        for edge in graph.edges {
            guard let source = nodes[edge.from.node], let target = nodes[edge.to.node] else { throw GraphDiagnostic("Connection references a missing node.",node:edge.to.node) }
            guard source.kind != .output, edge.from.port == "out", let input = target.kind.inputs.first(where: { $0.id == edge.to.port }) else {
                throw GraphDiagnostic("Unknown port. Choose an existing input/output.",node:target.id)
            }
            guard input.type == source.kind.outputType else { throw GraphDiagnostic("\(input.title) requires \(input.type.rawValue), received \(source.kind.outputType.rawValue).",node:target.id) }
            guard destinations.insert(edge.to).inserted else { throw GraphDiagnostic("An input accepts one connection. Replace its existing connection.",node:target.id) }
        }
        var ordered: [GraphNode] = []; var done: Set<UUID> = []; var visiting: Set<UUID> = []
        func visit(_ id: UUID) throws {
            guard !done.contains(id), let node = nodes[id] else { return }
            guard visiting.insert(id).inserted else { throw GraphDiagnostic("Cycle detected. Disconnect the feedback link.",node:id) }
            for edge in graph.edges where edge.to.node == id { try visit(edge.from.node) }
            visiting.remove(id); done.insert(id); ordered.append(node)
        }
        for node in graph.nodes { try visit(node.id) }
        if requireComplete {
            for node in graph.nodes {
                for port in node.kind.inputs where port.required && !destinations.contains(.init(node.id,port.id)) {
                    throw GraphDiagnostic("Connect \(node.kind.title)’s \(port.title) input (\(port.type.rawValue)).",node:node.id)
                }
            }
        }
        _ = try GraphSchedule(graph:graph,ordered:ordered)
        return ordered
    }
}

/// Image dependencies end at a render-pass boundary; value nodes are inline GPU expressions.
public struct GraphSchedule: Sendable {
    public struct Pass: Sendable {
        public let node: GraphNode
        public let verticalBlur: Bool
        public let inputs: [Int]
        public let imageInputs: [UUID:Int]
        public var slot: Int?
    }
    public let passes: [Pass]
    public let textureCount: Int
    public init(graph: ShaderGraph, ordered: [GraphNode]) throws {
        var reachable: Set<UUID> = []
        func include(_ id: UUID) {
            guard reachable.insert(id).inserted else { return }
            for edge in graph.edges where edge.to.node == id { include(edge.from.node) }
        }
        if let output = graph.nodes.first(where: { $0.kind == .output }) { include(output.id) }
        var passes: [Pass] = []; var produced: [UUID:Int] = [:]
        for node in ordered where reachable.contains(node.id) && node.kind.outputType == .image {
            var images = Set<UUID>(); var visited = Set<UUID>()
            func gather(_ id: UUID) {
                guard visited.insert(id).inserted, let n = graph.node(id) else { return }
                if n.kind.outputType == .image { images.insert(id); return }
                for edge in graph.edges where edge.to.node == id { gather(edge.from.node) }
            }
            for edge in graph.edges where edge.to.node == node.id { gather(edge.from.node) }
            let mapping = Dictionary(uniqueKeysWithValues:images.compactMap { id in produced[id].map { (id,$0) } })
            let inputs = mapping.values.sorted()
            passes.append(.init(node:node,verticalBlur:false,inputs:inputs,imageInputs:mapping,slot:nil))
            if node.kind == .effect(.blur), !node.bypassed {
                let horizontal = passes.count-1
                images = []; visited = []
                for edge in graph.edges where edge.to.node == node.id && edge.to.port != "image" { gather(edge.from.node) }
                let parameters = Dictionary(uniqueKeysWithValues:images.compactMap { id in produced[id].map { (id,$0) } })
                passes.append(.init(node:node,verticalBlur:true,inputs:parameters.values.sorted()+[horizontal],imageInputs:parameters,slot:nil))
            }
            produced[node.id] = passes.count-1
        }
        guard passes.count <= ShaderGraph.maximumPasses else { throw GraphDiagnostic("Graph exceeds 64 render passes. Remove effects or branches.",node:passes.last?.node.id) }
        var lastUse: [Int:Int] = [:]
        for (index,pass) in passes.enumerated() { for input in pass.inputs { lastUse[input] = index } }
        var active: [Int:Int] = [:]; var maximum = 0
        for index in passes.indices {
            if passes[index].node.kind != .output {
                let used = Set(active.values)
                guard let slot = (0..<ShaderGraph.maximumTextures).first(where: { !used.contains($0) }) else {
                    throw GraphDiagnostic("Graph needs more than 8 intermediate textures. Reduce simultaneous branches.",node:passes[index].node.id)
                }
                passes[index].slot = slot; active[index] = slot; maximum = max(maximum,slot+1)
            }
            // Free after allocating this pass: its input and output cannot alias.
            for producer in Array(active.keys) where (lastUse[producer] ?? producer) <= index { active[producer] = nil }
        }
        self.passes = passes; textureCount = maximum
    }
}

public struct GraphPoint: Equatable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double = 0, y: Double = 0) { self.x = x; self.y = y }
}
public struct GraphLayout: Equatable, Codable, Sendable {
    public var positions: [String:GraphPoint]
    public var pan: GraphPoint
    public var zoom: Double
    public init(positions: [String:GraphPoint] = [:], pan: GraphPoint = .init(), zoom: Double = 1) {
        self.positions = positions; self.pan = pan; self.zoom = zoom
    }
    public func validate() throws {
        func valid(_ p: GraphPoint) -> Bool { p.x.isFinite && p.y.isFinite && abs(p.x) <= 100_000 && abs(p.y) <= 100_000 }
        guard positions.count <= 128, positions.allSatisfy({ UUID(uuidString:$0.key) != nil && valid($0.value) }),
              valid(pan), zoom.isFinite, (0.25...2).contains(zoom) else { throw GraphDiagnostic("Invalid graph layout. Use finite positions and zoom from 25% to 200%.") }
    }
    public func position(_ id: UUID, index: Int) -> GraphPoint { positions[id.uuidString] ?? .init(x:Double(index%4)*240+24,y:Double(index/4)*400+24) }
}
