import Foundation

/// Linear-light RGB in the working space; the renderer encodes sRGB on output.
public struct SceneColor: Equatable, Codable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamp(red); self.green = Self.clamp(green); self.blue = Self.clamp(blue)
    }
    private static func clamp(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0 }
    public subscript(id: ParameterID) -> Double {
        switch id { case .solidRed: red; case .solidGreen: green; case .solidBlue: blue; default: 0 }
    }
    public func replacing(_ id: ParameterID, with value: Double) -> Self {
        Self(red: id == .solidRed ? value : red, green: id == .solidGreen ? value : green,
             blue: id == .solidBlue ? value : blue)
    }
    public var isValid: Bool { [red, green, blue].allSatisfy { $0.isFinite && (0...1).contains($0) } }
    public static let initial = Self(red: 0.24, green: 0.08, blue: 0.62)
}

public struct SceneSnapshot: Equatable, Codable, Sendable {
    public let source: SourceKind
    public let parameters: [String: ParameterValue]
    public let seed: UInt32
    public let effects: [EffectInstance]
    public let graph: ShaderGraph
    public private(set) var mappings: [VisualMapping] = []
    public private(set) var sync: SceneSync = .freeRun
    public var color: SceneColor { .init(red: number(.solidRed), green: number(.solidGreen), blue: number(.solidBlue)) }
    public init(color: SceneColor = .initial, seed: UInt32 = 1) {
        self.init(source: .solid, values: [.solidRed: .number(color.red), .solidGreen: .number(color.green), .solidBlue: .number(color.blue)], seed: seed)
    }
    public init(source: SourceKind, values: [ParameterID: ParameterValue] = [:], seed: UInt32 = 1, effects: [EffectInstance] = []) {
        self.effects = effects
        self.source = source; self.seed = seed
        var parameters = SourceRegistry.defaults
        for (id, value) in values where id != .seed {
            if let value = SourceRegistry.parameter(id).normalized(value) { parameters[id.rawValue] = value }
        }
        self.parameters = parameters
        graph = .chain(source: source, parameters: parameters, effects: effects)
    }
    private init(source: SourceKind, parameters: [String: ParameterValue], seed: UInt32, effects: [EffectInstance], graph: ShaderGraph? = nil) {
        self.source = source; self.parameters = parameters; self.seed = seed; self.effects = effects
        self.graph = graph ?? .chain(source:source,parameters:parameters,effects:effects)
    }
    private enum CodingKeys: String, CodingKey { case source, parameters, seed, effects, graph, mappings, sync }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decode(SourceKind.self, forKey: .source)
        parameters = try c.decode([String: ParameterValue].self, forKey: .parameters)
        seed = try c.decode(UInt32.self, forKey: .seed)
        effects = try c.decode([EffectInstance].self, forKey: .effects)
        graph = try c.decode(ShaderGraph.self, forKey: .graph)
        mappings = try c.decodeIfPresent([VisualMapping].self, forKey: .mappings) ?? []
        sync = try c.decodeIfPresent(SceneSync.self, forKey: .sync) ?? .freeRun
    }
    public func withMappings(_ mappings: [VisualMapping]) -> Self {
        guard mappings.count <= 128, Set(mappings.map(\.id)).count == mappings.count,
              mappings.allSatisfy({ (try? $0.validate()) != nil }) else { return self }
        var result = self; result.mappings = mappings; return result
    }
    public func withSync(_ sync: SceneSync) -> Self { var result = self; result.sync = sync; return result }
    private func retainingMappings(_ scene: Self) -> Self { scene.withMappings(mappings).withSync(sync) }
    public func value(_ id: ParameterID) -> ParameterValue {
        id == .seed ? .number(Double(seed)) : parameters[id.rawValue] ?? SourceRegistry.parameter(id).defaultValue
    }
    public func number(_ id: ParameterID) -> Double { if case let .number(v) = value(id) { v } else { 0 } }
    public func tint(_ id: ParameterID) -> SceneColor { if case let .color(v) = value(id) { v } else { .initial } }
    public func choice(_ id: ParameterID) -> String { if case let .choice(v) = value(id) { v } else { "" } }
    public func enabled(_ id: ParameterID) -> Bool { if case let .toggle(v) = value(id) { v } else { false } }
    public func validate() throws {
        guard mappings.count <= 128, Set(mappings.map(\.id)).count == mappings.count else { throw ProjectError.invalidValues }
        for mapping in mappings { try mapping.validate() }
        guard effects.count <= EffectRegistry.maximumEffects, Set(effects.map(\.id)).count == effects.count else { throw ProjectError.invalidValues }
        for effect in effects { try effect.validate() }
        guard Set(parameters.keys) == Set(SourceRegistry.defaults.keys), parameters.allSatisfy({ key, value in
            guard let id = ParameterID(rawValue: key) else { return false }
            return SourceRegistry.parameter(id).allows(value)
        }) else { throw ProjectError.invalidValues }
        try GraphValidator.validate(graph)
        if let chain = graph.chain {
            guard chain.source.kind == .source(source), chain.effects == effects, chain.source.values.allSatisfy({ parameters[$0.key] == $0.value }) else {
                throw GraphDiagnostic("Source/effect cache does not match the graph. Reopen a valid project.",node:chain.source.id)
            }
        }
    }
    private func rebuiltGraph(source: SourceKind, parameters: [String:ParameterValue], effects: [EffectInstance]) -> ShaderGraph {
        .chain(source:source,parameters:parameters,effects:effects,sourceID:graph.chain?.source.id ?? ShaderGraph.sourceID,
               outputID:graph.nodes.first(where: { $0.kind == .output })?.id ?? ShaderGraph.outputID)
    }
    func selecting(_ source: SourceKind) -> Self { retainingMappings(Self(source: source, parameters: parameters, seed: seed, effects: effects, graph:rebuiltGraph(source:source,parameters:parameters,effects:effects))) }
    func replacing(_ id: ParameterID, with value: ParameterValue) -> Self {
        guard source.definition.parameters.contains(where: { $0.id == id }),
              let value = SourceRegistry.parameter(id).normalized(value) else { return self }
        if id == .seed, case let .number(v) = value { return retainingMappings(Self(source: source, parameters: parameters, seed: UInt32(v), effects: effects, graph:graph)) }
        var parameters = parameters; parameters[id.rawValue] = value
        return retainingMappings(Self(source: source, parameters: parameters, seed: seed, effects: effects, graph:rebuiltGraph(source:source,parameters:parameters,effects:effects)))
    }
    public func withSeed(_ seed: UInt32) -> Self { retainingMappings(Self(source:source,parameters:parameters,seed:seed,effects:effects,graph:graph)) }
    public var canEditChain: Bool { graph.chain != nil }
    public func withGraph(_ graph: ShaderGraph) -> Self {
        if let chain = graph.chain, case let .source(source) = chain.source.kind {
            var parameters = parameters
            for (key,value) in chain.source.values { parameters[key] = value }
            return retainingMappings(Self(source:source,parameters:parameters,seed:seed,effects:chain.effects,graph:graph))
        }
        return retainingMappings(Self(source:source,parameters:parameters,seed:seed,effects:effects,graph:graph))
    }
    func withEffects(_ effects: [EffectInstance]) -> Self {
        retainingMappings(Self(source: source, parameters: parameters, seed: seed, effects: effects, graph:rebuiltGraph(source:source,parameters:parameters,effects:effects)))
    }
}

public enum SceneAction: Sendable {
    case setMappings([VisualMapping])
    case setSync(SceneSync)
    case setSeed(UInt32)
    case setGraph(ShaderGraph)
    case setNodeValue(UUID, String, ParameterValue)
    case addEffect(EffectInstance)
    case removeEffect(UUID)
    case moveEffect(UUID, Int)
    case bypassEffect(UUID, Bool)
    case setEffectValue(UUID, String, ParameterValue)
    case setParameter(ParameterID, Double)
    case setColor(SceneColor)
    case selectSource(SourceKind)
    case setValue(ParameterID, ParameterValue)
}

public enum SceneReducer {
    public static func reduce(_ scene: SceneSnapshot, _ action: SceneAction) -> SceneSnapshot {
        if case let .setMappings(mappings) = action { return scene.withMappings(mappings) }
        if case let .setSync(sync) = action { return scene.withSync(sync) }
        if case let .setSeed(seed) = action { return scene.withSeed(seed) }
        if case let .setGraph(graph) = action { return scene.withGraph(graph) }
        if case let .setNodeValue(id,key,value) = action, let node = scene.graph.node(id) { return scene.withGraph(scene.graph.replacing(node.replacing(key,with:value))) }
        guard scene.canEditChain else { return scene }
        switch action {
        case .setMappings, .setSync, .setSeed, .setGraph, .setNodeValue: return scene
        case let .addEffect(effect):
            if scene.effects.count < EffectRegistry.maximumEffects, !scene.graph.nodes.contains(where: { $0.id == effect.id }), (try? effect.validate()) != nil {
                return scene.withEffects(scene.effects + [effect])
            } else { return scene }
        case let .removeEffect(id): return scene.withEffects(scene.effects.filter { $0.id != id })
        case let .moveEffect(id, destination):
            if let index = scene.effects.firstIndex(where: { $0.id == id }), scene.effects.indices.contains(destination) {
                var effects = scene.effects; effects.insert(effects.remove(at: index), at: destination)
                return scene.withEffects(effects)
            } else { return scene }
        case let .bypassEffect(id, bypass): return scene.withEffects(scene.effects.map { $0.id == id ? $0.bypassing(bypass) : $0 })
        case let .setEffectValue(id, key, value): return scene.withEffects(scene.effects.map { $0.id == id ? $0.replacing(key, value) : $0 })
        case let .setParameter(id, value): return scene.replacing(id, with: .number(value))
        case let .setValue(id, value): return scene.replacing(id, with: value)
        case let .selectSource(source): return scene.selecting(source)
        case let .setColor(value):
            return scene.replacing(.solidRed, with: .number(value.red)).replacing(.solidGreen, with: .number(value.green))
                .replacing(.solidBlue, with: .number(value.blue))
        }
    }
}

/// Value history keeps transient drag updates separate from committed edits.
public struct SceneHistory: Sendable {
    public private(set) var scene: SceneSnapshot
    public private(set) var past: [SceneSnapshot] = []
    public private(set) var future: [SceneSnapshot] = []
    private var editStart: SceneSnapshot?
    public var canUndo: Bool { !past.isEmpty || (editStart != nil && editStart != scene) }
    public var canRedo: Bool { !future.isEmpty && editStart == nil }
    public init(scene: SceneSnapshot = .init()) { self.scene = scene }
    public mutating func beginEdit() { if editStart == nil { editStart = scene } }
    public mutating func send(_ action: SceneAction) {
        switch action {
        case .setMappings, .setSync, .selectSource, .addEffect, .removeEffect, .moveEffect, .bypassEffect, .setGraph: endEdit()
        default: break
        }
        let next = SceneReducer.reduce(scene, action)
        guard next != scene else { return }
        if editStart == nil { appendPast(scene); future.removeAll() }
        scene = next
    }
    public mutating func endEdit() {
        guard let start = editStart else { return }
        editStart = nil
        if start != scene { appendPast(start); future.removeAll() }
    }
    public mutating func undo() {
        endEdit()
        guard let previous = past.popLast() else { return }
        future.append(scene); scene = previous
    }
    public mutating func redo() {
        endEdit()
        guard let next = future.popLast() else { return }
        appendPast(scene); scene = next
    }
    private mutating func appendPast(_ snapshot: SceneSnapshot) {
        past.append(snapshot)
        if past.count > 200 { past.removeFirst(past.count - 200) }
    }
}

public struct RenderFrame: Equatable, Sendable {
    public let scene: SceneSnapshot
    public let time: TimeInterval
    public init(scene: SceneSnapshot, time: TimeInterval) { self.scene = scene; self.time = time }
}

public struct RenderClock: Sendable {
    private let origin = ContinuousClock.now
    private let fixedTime: TimeInterval?
    public init(fixedTime: TimeInterval? = nil) { self.fixedTime = fixedTime }
    public var time: TimeInterval {
        if let fixedTime { return fixedTime }
        let duration = origin.duration(to: .now).components
        return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
    }
}
