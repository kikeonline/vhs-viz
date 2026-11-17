import Foundation
import Darwin

public enum PresetError: Error, LocalizedError {
    case corrupt, unsupportedVersion, changed, readOnly
    public var errorDescription: String? {
        switch self {
        case .corrupt: "This is not a valid VHS preset."
        case .unsupportedVersion: "This preset needs a compatible version of VHS."
        case .changed: "The scene changed while the preset was preparing. Load again to replace it."
        case .readOnly: "Factory presets are read-only. Save a user copy instead."
        }
    }
}

/// Portable content only. No project, host, device, window or library identity.
public struct PresetDocument: Equatable, Sendable {
    public let name: String
    public let scene: SceneSnapshot
    public init(name: String, scene: SceneSnapshot) { self.name = name; self.scene = scene }
    public func named(_ name: String) -> Self { .init(name:name,scene:scene) }
    public func validate() throws {
        guard try ProjectDocument.validatedName(name) == name else { throw ProjectError.invalidName }
        try scene.validate()
    }
}
public enum PresetCodec {
    public static let maximumBytes = ProjectCodec.maximumBytes
    private struct Envelope: Encodable {
        let format = "vhs-preset"
        let version = 1
        let sceneVersion = ProjectDocument.currentVersion
        let name: String
        let scene: SceneSnapshot
    }
    public static func encode(_ preset: PresetDocument) throws -> Data {
        try preset.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        let data = try encoder.encode(Envelope(name:preset.name,scene:preset.scene))
        guard data.count <= maximumBytes else { throw ProjectError.tooLarge }
        return data
    }
    public static func decode(_ data: Data) throws -> PresetDocument {
        guard data.count <= maximumBytes else { throw ProjectError.tooLarge }
        struct Header: Decodable { let format: String; let version: Int; let sceneVersion: Int; let name: String }
        guard let header = try? JSONDecoder().decode(Header.self,from:data), header.format == "vhs-preset",
              let envelope = try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let scene = envelope["scene"] else { throw PresetError.corrupt }
        guard header.version == 1 else { throw PresetError.unsupportedVersion }
        // Reuse the project's validated migrations; identity exists only during decoding.
        let project: [String:Any] = ["schemaVersion":header.sceneVersion,"id":ShaderGraph.sourceID.uuidString,
            "name":header.name,"scene":scene,"graphLayout":["positions":[:],"pan":["x":0,"y":0],"zoom":1]]
        let document = try ProjectCodec.decode(JSONSerialization.data(withJSONObject:project))
        return .init(name:document.name,scene:document.scene)
    }
    /// Compile before callers commit. Failure has no side effects on scene/history/output.
    public static func prepare(_ preset: PresetDocument,
        compile: @Sendable (ShaderGraph) async throws -> Void) async throws -> SceneSnapshot {
        try preset.validate()
        try await compile(preset.scene.graph)
        try Task.checkCancellation()
        return preset.scene
    }
}

/// Synchronous primitives are used only from PresetLibrary's actor executor.
public struct PresetStore: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func list() throws -> [String] {
        guard FileManager.default.fileExists(atPath:directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)
            .filter { $0.pathExtension == "vhspreset" && !$0.lastPathComponent.hasPrefix(".") }
            .map { $0.deletingPathExtension().lastPathComponent }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    private func url(_ name: String) throws -> URL {
        let name = try ProjectDocument.validatedName(name)
        return directory.appendingPathComponent(name).appendingPathExtension("vhspreset")
    }
    public func read(_ name: String) throws -> PresetDocument { try readFile(url(name)).named(name) }
    public func readFile(_ url: URL) throws -> PresetDocument {
        guard url.isFileURL else { throw PresetError.corrupt }
        guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0) <= PresetCodec.maximumBytes else { throw ProjectError.tooLarge }
        return try PresetCodec.decode(Data(contentsOf:url))
    }
    public func save(_ preset: PresetDocument, overwrite: Bool = false, beforeCommit: () throws -> Void = {}) throws {
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let destination = try url(preset.name)
        if let existing = try list().first(where: { $0.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:nil) == preset.name.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:nil) }), existing != preset.name || !overwrite { throw ProjectError.destinationExists }
        try writeFile(preset,to:destination,overwrite:overwrite,beforeCommit:beforeCommit)
    }
    public func writeFile(_ preset: PresetDocument, to destination: URL, overwrite: Bool = false,
                          beforeCommit: () throws -> Void = {}) throws {
        guard destination.isFileURL else { throw PresetError.corrupt }
        let data = try PresetCodec.encode(preset)
        let temp = destination.deletingLastPathComponent().appendingPathComponent(".vhs-preset-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at:temp) }
        try data.write(to:temp,options:.withoutOverwriting)
        let handle = try FileHandle(forWritingTo:temp)
        do { try handle.synchronize(); try handle.close() } catch { try? handle.close(); throw error }
        try beforeCommit()
        let status = temp.withUnsafeFileSystemRepresentation { source in
            destination.withUnsafeFileSystemRepresentation { target in
                overwrite ? Darwin.rename(source!,target!) : Darwin.link(source!,target!)
            }
        }
        guard status == 0 else {
            if errno == EEXIST { throw ProjectError.destinationExists }
            throw POSIXError(POSIXErrorCode(rawValue:errno) ?? .EIO)
        }
    }
    public func rename(_ name: String, to newName: String) throws {
        guard name != newName else { return }
        let copy = try read(name).named(ProjectDocument.validatedName(newName))
        try save(copy)
        try delete(name)
    }
    public func delete(_ name: String) throws { try FileManager.default.removeItem(at:url(name)) }
}
public actor PresetLibrary {
    public static var defaultDirectory: URL {
        FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            .appendingPathComponent("VHS/Presets",isDirectory:true)
    }
    private let store: PresetStore
    public init(directory: URL = PresetLibrary.defaultDirectory) { store = .init(directory:directory) }
    public func list() throws -> [String] { try store.list() }
    public func read(_ name: String) throws -> PresetDocument { try store.read(name) }
    public func readFile(_ url: URL) throws -> PresetDocument { try store.readFile(url) }
    public func save(_ preset: PresetDocument, overwrite: Bool = false) throws { try store.save(preset,overwrite:overwrite) }
    public func rename(_ name: String, to newName: String) throws { try store.rename(name,to:newName) }
    public func delete(_ name: String) throws { try store.delete(name) }
    public func export(_ preset: PresetDocument, to url: URL, overwrite: Bool = false) throws { try store.writeFile(preset,to:url,overwrite:overwrite) }
}

public enum FactoryPresets {
    private static func id(_ n: Int) -> UUID { UUID(uuidString:String(format:"70000000-0000-4000-8000-%012d",n))! }
    public static var all: [PresetDocument] {
        let solid = PresetDocument(name:"Signal Violet",scene:.init())
        let noise = SceneSnapshot(source:.noise,seed:73)
        var mapping = VisualMapping(id:id(10),target:.init(node:ShaderGraph.sourceID,key:ParameterID.noiseScale.rawValue))
        mapping.source = .peak; mapping.upper = 8; mapping.smoothing = 0.15
        let reactive = PresetDocument(name:"Audio Grain",scene:noise.withMappings([mapping]))
        let a = GraphNode(id:id(1),kind:.source(.gradient))
        let b = GraphNode(id:id(2),kind:.source(.oscillator))
        let amount = GraphNode(id:id(3),kind:.scalar)
        let mix = GraphNode(id:id(4),kind:.imageMix)
        let out = GraphNode(id:ShaderGraph.outputID,kind:.output)
        let graph = ShaderGraph(nodes:[a,b,amount,mix,out],edges:[
            .init(from:.init(a.id),to:.init(mix.id,"a")),.init(from:.init(b.id),to:.init(mix.id,"b")),
            .init(from:.init(amount.id),to:.init(mix.id,"amount")),.init(from:.init(mix.id),to:.init(out.id,"image"))])
        let blend = PresetDocument(name:"Gradient Oscillator Blend",scene:SceneSnapshot().withGraph(graph))
        return [solid,reactive,blend]
    }
}
