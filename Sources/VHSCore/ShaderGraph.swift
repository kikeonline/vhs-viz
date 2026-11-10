import Foundation

public enum PortType: String, Codable, Sendable { case scalar, vector, color, image }
public struct GraphPort: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let type: PortType
    public let required: Bool
    public init(_ id: String, _ title: String, _ type: PortType, required: Bool = true) {
        self.id = id; self.title = title; self.type = type; self.required = required
    }
}
public enum NodeKind: Equatable, Hashable, Codable, Sendable {
    case source(SourceKind), effect(EffectKind)
    case scalar, vector, color, uv, time, scalarAdd, scalarMultiply, sine
    case vectorAdd, vectorMultiply, composeColor, luminance, sampleImage, colorMix, imageFromColor, imageMix, output
    public var title: String {
        switch self {
        case let .source(kind): kind.definition.title
        case let .effect(kind): kind.definition.title
        case .scalar: "Number"; case .vector: "Vector"; case .color: "Color"
        case .uv: "UV"; case .time: "Time"; case .scalarAdd: "Add Numbers"; case .scalarMultiply: "Multiply Numbers"
        case .sine: "Sine"; case .vectorAdd: "Add Vectors"; case .vectorMultiply: "Multiply Vectors"
        case .composeColor: "Compose Color"; case .luminance: "Luminance"; case .sampleImage: "Sample Image"
        case .colorMix: "Mix Colors"; case .imageFromColor: "Color to Image"; case .imageMix: "Mix Images"; case .output: "Output"
        }
    }
    public var outputType: PortType {
        switch self {
        case .source, .effect, .imageFromColor, .imageMix, .output: .image
        case .vector, .uv, .vectorAdd, .vectorMultiply: .vector
        case .color, .composeColor, .sampleImage, .colorMix: .color
        default: .scalar
        }
    }
    public var parameters: [EffectParameter] {
        switch self {
        case let .source(kind): kind.definition.parameters.filter { $0.id != .seed }.map {
            EffectParameter(id: $0.id.rawValue, title: $0.title, kind: $0.kind, defaultValue: $0.defaultValue, unit: $0.unit)
        }
        case let .effect(kind): kind.definition.parameters
        case .scalar: [.init(id:"value",title:"Value",kind:.number(-1000...1000),defaultValue:.number(0.5),unit:"")]
        case .vector: ["x","y"].map { .init(id:$0,title:$0.uppercased(),kind:.number(-1000...1000),defaultValue:.number(0.5),unit:"") }
        case .color: [.init(id:"value",title:"Color",kind:.color,defaultValue:.color(.initial),unit:"")]
        default: []
        }
    }
    public var inputs: [GraphPort] {
        var ports: [GraphPort] = []
        if case .effect = self { ports.append(.init("image","Image",.image)) }
        switch self {
        case .scalarAdd, .scalarMultiply: ports = [.init("a","A",.scalar),.init("b","B",.scalar)]
        case .vectorAdd, .vectorMultiply: ports = [.init("a","A",.vector),.init("b","B",.vector)]
        case .sine: ports = [.init("value","Value",.scalar)]
        case .composeColor: ports = ["red","green","blue"].map { .init($0,$0.capitalized,.scalar) }
        case .luminance: ports = [.init("color","Color",.color)]
        case .sampleImage: ports = [.init("image","Image",.image),.init("uv","UV",.vector)]
        case .colorMix: ports = [.init("a","A",.color),.init("b","B",.color),.init("amount","Amount",.scalar)]
        case .imageMix: ports = [.init("a","A",.image),.init("b","B",.image),.init("amount","Amount",.scalar)]
        case .imageFromColor: ports = [.init("color","Color",.color)]
        case .output: ports = [.init("image","Image",.image)]
        default: break
        }
        for p in parameters {
            switch p.kind {
            case .number, .integer: ports.append(.init(p.id,p.title,.scalar,required:false))
            case .color: ports.append(.init(p.id,p.title,.color,required:false))
            default: break
            }
        }
        return ports
    }
    public static var library: [Self] {
        SourceKind.allCases.map(Self.source) + EffectKind.allCases.map(Self.effect) + [
            .scalar,.vector,.color,.uv,.time,.scalarAdd,.scalarMultiply,.sine,.vectorAdd,.vectorMultiply,
            .composeColor,.luminance,.sampleImage,.colorMix,.imageFromColor,.imageMix
        ]
    }
}
public struct GraphNode: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let kind: NodeKind
    public let values: [String: ParameterValue]
    public let bypassed: Bool
    public init(id: UUID = UUID(), kind: NodeKind, values: [String:ParameterValue]? = nil, bypassed: Bool = false) {
        self.id = id; self.kind = kind; self.bypassed = bypassed
        self.values = values ?? Dictionary(uniqueKeysWithValues: kind.parameters.map { ($0.id,$0.defaultValue) })
    }
    private enum CodingKeys: String, CodingKey { case id, kind, values, bypassed }
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy:CodingKeys.self)
        id = try container.decode(UUID.self,forKey:.id)
        do { kind = try container.decode(NodeKind.self,forKey:.kind) }
        catch { throw GraphDiagnostic("Unknown node kind. Use a supported node or a compatible VHS version.",node:id) }
        do {
            values = try container.decode([String:ParameterValue].self,forKey:.values)
            bypassed = try container.decode(Bool.self,forKey:.bypassed)
        } catch { throw GraphDiagnostic("Invalid node parameter types or bypass state.",node:id) }
    }
    public func replacing(_ key: String, with value: ParameterValue) -> Self {
        guard let p = kind.parameters.first(where: { $0.id == key }) else { return self }
        let result: ParameterValue
        switch (p.kind,value) {
        case let (.number(r),.number(v)): result = .number(v.isFinite ? min(r.upperBound,max(r.lowerBound,v)) : r.lowerBound)
        case let (.integer(r),.number(v)): result = .number(v.isFinite ? min(r.upperBound,max(r.lowerBound,v.rounded())) : r.lowerBound)
        default: guard Self.allows(p,value) else { return self }; result = value
        }
        var values = values; values[key] = result
        return .init(id:id,kind:kind,values:values,bypassed:bypassed)
    }
    static func allows(_ p: EffectParameter, _ value: ParameterValue) -> Bool {
        switch (p.kind,value) {
        case let (.integer(r),.number(v)): v.isFinite && r.contains(v) && v.rounded() == v
        case let (.choice(options),.choice(v)): options.contains { $0.id == v }
        case (.toggle,.toggle): true
        default: p.allows(value)
        }
    }
}
public struct GraphEndpoint: Equatable, Hashable, Codable, Sendable {
    public let node: UUID
    public let port: String
    public init(_ node: UUID, _ port: String = "out") { self.node = node; self.port = port }
}
public struct GraphEdge: Equatable, Codable, Sendable {
    public let from: GraphEndpoint
    public let to: GraphEndpoint
    public init(from: GraphEndpoint, to: GraphEndpoint) { self.from = from; self.to = to }
}
public struct ShaderGraph: Equatable, Codable, Sendable {
    public static let maximumNodes = 64
    public static let maximumPasses = 64
    public static let maximumTextures = 8
    public static let sourceID = UUID(uuidString:"00000000-0000-4000-8000-000000000001")!
    public static let outputID = UUID(uuidString:"00000000-0000-4000-8000-000000000002")!
    public let version: Int
    public let nodes: [GraphNode]
    public let edges: [GraphEdge]
    public init(nodes: [GraphNode], edges: [GraphEdge], version: Int = 1) { self.version = version; self.nodes = nodes; self.edges = edges }
    public func node(_ id: UUID) -> GraphNode? { nodes.first { $0.id == id } }
    public func input(_ node: UUID, _ port: String) -> GraphEndpoint? { edges.first { $0.to == .init(node,port) }?.from }
    public func replacing(_ node: GraphNode) -> Self { .init(nodes:nodes.map { $0.id == node.id ? node : $0 },edges:edges) }
    public func adding(_ node: GraphNode) -> Self { .init(nodes:nodes+[node],edges:edges) }
    public func removing(_ id: UUID) -> Self {
        guard node(id)?.kind != .output else { return self }
        return .init(nodes:nodes.filter { $0.id != id },edges:edges.filter { $0.from.node != id && $0.to.node != id })
    }
    public func connecting(_ from: GraphEndpoint?, to: GraphEndpoint) throws -> Self {
        var edges = edges.filter { $0.to != to }
        if let from { edges.append(.init(from:from,to:to)) }
        let graph = Self(nodes:nodes,edges:edges)
        _ = try GraphValidator.validate(graph, requireComplete:false)
        return graph
    }
    public func duplicated(_ id: UUID, newID: UUID = UUID()) -> Self {
        guard let node = node(id), node.kind != .output else { return self }
        return .init(nodes:nodes+[.init(id:newID,kind:node.kind,values:node.values,bypassed:node.bypassed)],
                     edges:edges+edges.filter { $0.to.node == id }.map { .init(from:$0.from,to:.init(newID,$0.to.port)) })
    }
    public static func chain(source: SourceKind, parameters: [String:ParameterValue], effects: [EffectInstance], sourceID: UUID = Self.sourceID, outputID: UUID = Self.outputID) -> Self {
        let values = Dictionary(uniqueKeysWithValues: NodeKind.source(source).parameters.map { ($0.id, parameters[$0.id] ?? $0.defaultValue) })
        var nodes = [GraphNode(id:sourceID,kind:.source(source),values:values)]
        var edges: [GraphEdge] = []; var previous = sourceID
        for effect in effects {
            nodes.append(.init(id:effect.id,kind:.effect(effect.kind),values:effect.parameters,bypassed:effect.bypassed))
            edges.append(.init(from:.init(previous),to:.init(effect.id,"image"))); previous = effect.id
        }
        nodes.append(.init(id:outputID,kind:.output))
        edges.append(.init(from:.init(previous),to:.init(outputID,"image")))
        return .init(nodes:nodes,edges:edges)
    }
    public var chain: (source: GraphNode, effects: [EffectInstance])? {
        guard let output = nodes.first(where: { $0.kind == .output }), nodes.filter({ $0.kind == .output }).count == 1 else { return nil }
        var visited: Set<UUID> = [output.id]; var effects: [EffectInstance] = []; var next = input(output.id,"image")
        while let endpoint = next, let node = node(endpoint.node), endpoint.port == "out", visited.insert(node.id).inserted {
            if case let .source(kind) = node.kind {
                guard visited.count == nodes.count, edges.count == nodes.count-1, !edges.contains(where: { $0.to.node == node.id }), effects.count <= EffectRegistry.maximumEffects else { return nil }
                _ = kind
                return (node,effects.reversed())
            }
            guard case let .effect(kind) = node.kind, edges.filter({ $0.to.node == node.id }).count == 1 else { return nil }
            var effect = EffectInstance(id:node.id,kind:kind)
            for (key,value) in node.values { effect = effect.replacing(key,value) }
            effects.append(effect.bypassing(node.bypassed)); next = input(node.id,"image")
        }
        return nil
    }
}

public struct GraphParameterTarget: Equatable, Hashable, Codable, Sendable {
    public let node: UUID
    public let key: String
    public init(node: UUID, key: String) { self.node = node; self.key = key }
    public func definition(in graph: ShaderGraph) -> EffectParameter? {
        graph.node(node)?.kind.parameters.first { $0.id == key && Self.eligible($0.kind) }
    }
    public var unavailableMessage: String { "Parameter unavailable: \(node.uuidString) / \(key). Restore the node or choose a new target explicitly." }
    public static func eligible(_ kind: ParameterKind) -> Bool { if case .number = kind { true } else { false } }
}
