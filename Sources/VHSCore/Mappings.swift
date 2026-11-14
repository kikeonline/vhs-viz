import Foundation

public enum MappingSource: String, Codable, CaseIterable, Sendable {
    case rms, peak, low, mid, high, transient, note, gate, velocity, cc
    public var isMIDI: Bool { [.note, .gate, .velocity, .cc].contains(self) }
    public var title: String { rawValue == "cc" ? "CC" : rawValue == "rms" ? "RMS" : rawValue.capitalized }
}
public enum SceneSync: String, Codable, Sendable { case freeRun, followDAW }
public struct VisualMapping: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var target: GraphParameterTarget
    public var source: MappingSource = .rms
    public var channel: Int? = nil
    public var number: Int? = nil
    public var lower = 0.0
    public var upper = 1.0
    public var inverted = false
    public var curve = 1.0
    public var smoothing = 0.0
    public var enabled = true
    public init(id: UUID = UUID(), target: GraphParameterTarget) { self.id = id; self.target = target }
    public func validate() throws {
        guard target.key.utf8.count <= 128, channel == nil || (1...16).contains(channel!),
              number == nil || (0...127).contains(number!), source != .cc || number != nil,
              lower.isFinite, upper.isFinite, abs(lower) <= 100_000, abs(upper) <= 100_000,
              curve.isFinite, (0.1...8).contains(curve), smoothing.isFinite, (0...10).contains(smoothing) else { throw ProjectError.invalidValues }
    }
    public func conflicts(with other: Self) -> Bool {
        guard source.isMIDI, other.source.isMIDI else { return false }
        let sameFamily = (source == .cc) == (other.source == .cc)
        return id != other.id && sameFamily && (channel == nil || other.channel == nil || channel == other.channel)
            && (number == nil || other.number == nil || number == other.number)
    }
    public func unavailable(in graph: ShaderGraph) -> Bool {
        target.definition(in: graph) == nil || graph.input(target.node, target.key) != nil
    }
}
/// Transient normalized controls. Adapters publish snapshots off their callbacks.
public struct MappingInputs: Sendable {
    public struct Note: Sendable {
        public let channel: Int, number: Int
        public let velocity: Double
        public init(channel: Int, number: Int, velocity: Double) { self.channel = channel; self.number = number; self.velocity = velocity }
    }
    public var audio: [MappingSource: Double] = [:]
    public var notes: [Note] = []
    public var controllers: [Int: Double] = [:] // (channel-1)*128 + controller
    public var midiAvailable = false
    public init() {}
    public func value(for mapping: VisualMapping) -> Double? {
        if !mapping.source.isMIDI { return audio[mapping.source].flatMap { $0.isFinite ? min(1,max(0,$0)) : nil } }
        guard midiAvailable else { return nil }
        let channels = mapping.channel.map { [$0] } ?? Array(1...16)
        if mapping.source == .cc {
            guard let number = mapping.number else { return nil }
            return channels.compactMap { controllers[($0-1)*128+number] }.filter(\.isFinite).max().map { min(1,max(0,$0)) }
        }
        let held = notes.filter { channels.contains($0.channel) && (mapping.number == nil || mapping.number == $0.number) && $0.velocity.isFinite && $0.velocity > 0 }
        // Highest-note priority; ties choose greatest velocity. Release falls back to next held note.
        let note = held.max { $0.number == $1.number ? $0.velocity < $1.velocity : $0.number < $1.number }
        guard let note else { return nil }
        switch mapping.source {
        case .gate: return 1
        case .velocity: return min(1,note.velocity)
        case .note: return Double(note.number)/127
        default: return nil
        }
    }
}
/// One instance, one display/control-thread owner. No mutation of document/history.
public struct MappingEngine: Sendable {
    private var smoothed: [UUID: Double] = [:]
    private var definitions: [UUID: VisualMapping] = [:]
    public private(set) var effective: [GraphParameterTarget: Double] = [:]
    public init() {}
    public mutating func reset() { self = Self() }
    public mutating func evaluate(_ scene: SceneSnapshot, inputs: MappingInputs, deltaTime: Double) -> SceneSnapshot {
        let validIDs = Set(scene.mappings.map(\.id))
        smoothed = smoothed.filter { validIDs.contains($0.key) }; definitions = definitions.filter { validIDs.contains($0.key) }
        var offsets: [GraphParameterTarget: Double] = [:]
        for m in scene.mappings {
            guard m.enabled, !m.unavailable(in: scene.graph), (try? m.validate()) != nil else { smoothed[m.id] = nil; continue }
            if definitions[m.id] != m { smoothed[m.id] = nil; definitions[m.id] = m }
            let desired: Double
            if let raw = inputs.value(for: m) {
                let value = pow(m.inverted ? 1-raw : raw,m.curve)
                desired = m.lower + (m.upper-m.lower)*value
            } else { desired = 0 } // Disconnect/release means no contribution, even for inversion/range floor.
            let dt = deltaTime.isFinite ? max(0,deltaTime) : 0
            let alpha = m.smoothing == 0 ? 1 : -expm1(-dt/m.smoothing)
            let previous = smoothed[m.id] ?? 0
            let value = previous + (desired-previous)*alpha
            smoothed[m.id] = abs(value) < 1e-9 ? 0 : value
            offsets[m.target,default:0] += smoothed[m.id]!
        }
        effective = [:]
        var graph = scene.graph
        for (target,offset) in offsets {
            guard let node = graph.node(target.node), case let .number(base) = scene.graph.node(target.node)?.values[target.key],
                  let p = target.definition(in:scene.graph), case let .number(range) = p.kind else { continue }
            let result = min(range.upperBound,max(range.lowerBound,base+offset))
            effective[target] = result
            graph = graph.replacing(node.replacing(target.key,with:.number(result)))
        }
        return scene.withGraph(graph)
    }
}

/// Explicit confirmation policy shared by standalone and host editors.
public enum MappingLearn {
    public static func candidate(_ original: VisualMapping, channel: Int, number: Int, note: Bool, omni: Bool) -> VisualMapping {
        var result = original
        result.source = note ? .gate : .cc; result.channel = omni ? nil : channel; result.number = number
        return result
    }
    public static func confirm(_ candidate: VisualMapping, in mappings: [VisualMapping], replaceConflicts: Bool) -> [VisualMapping]? {
        guard (try? candidate.validate()) != nil else { return nil }
        let conflicts = mappings.filter { candidate.conflicts(with:$0) }
        guard conflicts.isEmpty || replaceConflicts else { return nil }
        return mappings.filter { $0.id != candidate.id && (!replaceConflicts || !candidate.conflicts(with:$0)) } + [candidate]
    }
}
