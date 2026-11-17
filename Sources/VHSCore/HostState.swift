import Foundation

/// Fixed host IDs never depend on graph order, node kind or preset identity.
public struct HostAutomationBinding: Equatable, Codable, Sendable, Identifiable {
    public static let capacity = 256
    public static let firstParameterID: UInt32 = 0x2000
    public let slot: Int
    public let target: GraphParameterTarget
    public let enabled: Bool
    public var id: Int { slot }
    public var parameterID: UInt32 { Self.firstParameterID + UInt32(slot) }
    public init(slot: Int, target: GraphParameterTarget, enabled: Bool = true) { self.slot = slot; self.target = target; self.enabled = enabled }
    public func range(in graph: ShaderGraph) -> ClosedRange<Double>? {
        guard enabled, graph.input(target.node,target.key) == nil,
              let definition = target.definition(in:graph), case let .number(range) = definition.kind else { return nil }
        return range
    }
    public func normalized(in graph: ShaderGraph) -> Double? {
        guard let range = range(in:graph), case let .number(value) = graph.node(target.node)?.values[target.key] else { return nil }
        return (value-range.lowerBound)/(range.upperBound-range.lowerBound)
    }
    /// Host-owned base values precede MIDI/audio offsets. No reducer/history mutation.
    public static func applying(_ bindings: [Self], values: [Int:Double], to scene: SceneSnapshot) -> SceneSnapshot {
        var graph = scene.graph
        for binding in bindings {
            guard let value = values[binding.slot], value.isFinite, (0...1).contains(value),
                  let range = binding.range(in:graph), let node = graph.node(binding.target.node) else { continue }
            graph = graph.replacing(node.replacing(binding.target.key,with:.number(range.lowerBound+value*(range.upperBound-range.lowerBound))))
        }
        return scene.withGraph(graph)
    }
}
public struct HostDocument: Equatable, Sendable {
    public let project: ProjectDocument
    public let bindings: [HostAutomationBinding]
    public init(project: ProjectDocument = .init(name:"Plug-in Scene"), bindings: [HostAutomationBinding] = []) {
        self.project = project; self.bindings = bindings
    }
    public func validate() throws {
        try project.validate()
        guard bindings.count <= HostAutomationBinding.capacity,
              Set(bindings.map(\.slot)).count == bindings.count,
              Set(bindings.map(\.target)).count == bindings.count,
              bindings.allSatisfy({ (0..<HostAutomationBinding.capacity).contains($0.slot) && $0.target.key.utf8.count <= 128 }) else { throw ProjectError.invalidValues }
    }
}
public enum HostDocumentCodec {
    public static let maximumBytes = 131072
    private struct Envelope: Codable {
        let format: String
        let version: Int
        let project: Data
        let bindings: [HostAutomationBinding]
    }
    public static func encode(_ document: HostDocument) throws -> Data {
        try document.validate()
        let data = try JSONEncoder().encode(Envelope(format:"vhs-host",version:1,
            project:ProjectCodec.encode(document.project),bindings:document.bindings))
        guard data.count <= maximumBytes else { throw ProjectError.tooLarge }
        return data
    }
    public static func decode(_ data: Data) throws -> HostDocument {
        guard data.count <= maximumBytes else { throw ProjectError.tooLarge }
        struct Header: Decodable { let format: String? }
        let format = try JSONDecoder().decode(Header.self,from:data).format
        if format == nil { return .init(project:try ProjectCodec.decode(data)) } // legacy schema-1…5 project states
        guard format == "vhs-host" else { throw ProjectError.corrupt }
        let envelope = try JSONDecoder().decode(Envelope.self,from:data)
        guard envelope.version == 1 else { throw ProjectError.unsupportedVersion(envelope.version) }
        let document = HostDocument(project:try ProjectCodec.decode(envelope.project),bindings:envelope.bindings)
        try document.validate(); return document
    }
}

public struct HostTransport: Equatable, Sendable {
    public var beats = 0.0, tempo = 0.0, sampleRate = 48_000.0
    public var samplePosition: Int64 = 0
    public var playing = false, valid = false, musicalPositionValid = false, tempoValid = false, offline = false
    public init() {}
}
/// Follow DAW is explicitly beat-based: one quarter note = one animation second.
/// Missing context holds the last valid beat; Free Run uses the existing clock.
public struct HostVisualClock: Sendable {
    public private(set) var heldBeats = 0.0
    public private(set) var status = "Host timing unavailable; holding last position"
    public init() {}
    public mutating func time(mode: SceneSync, transport: HostTransport?, freeRun: Double) -> Double {
        guard mode == .followDAW else { status = "Free Run · seconds"; return freeRun }
        guard let t = transport, t.valid, !t.offline else {
            status = "Host timing unavailable; holding last position"; return heldBeats
        }
        let beats: Double
        if t.musicalPositionValid && t.beats.isFinite { beats = t.beats }
        else if t.tempoValid && t.tempo.isFinite && t.tempo > 0 && t.sampleRate.isFinite && t.sampleRate > 0 {
            beats = Double(t.samplePosition)/t.sampleRate*t.tempo/60
        } else { status = "Host beat position unavailable; holding last position"; return heldBeats }
        guard beats.isFinite else { return heldBeats }
        heldBeats = beats
        status = t.playing ? "Follow DAW · beats" : "Host stopped · holding beat position"
        return beats
    }
}
