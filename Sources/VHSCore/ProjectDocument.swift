import Foundation

public enum ProjectError: Error, LocalizedError, Equatable {
    case invalidName, invalidValues, corrupt, unsupportedVersion(Int), tooLarge, destinationExists
    public var errorDescription: String? {
        switch self {
        case .invalidName: "Use a name of 1–120 characters without slashes, colons, or control characters."
        case .invalidValues: "The project contains invalid scene values."
        case .corrupt: "This file is not a valid VHS project. Choose another .vhsproject file."
        case let .unsupportedVersion(version): version > ProjectDocument.currentVersion
            ? "This project needs a newer version of VHS (file version \(version))."
            : "This project's file version (\(version)) is not supported."
        case .tooLarge: "This project exceeds the supported file size of 8 MB."
        case .destinationExists: "A project with that name already exists. Choose a different name."
        }
    }
}

public struct ProjectDocument: Codable, Equatable, Sendable {
    public static let currentVersion = 5
    public let schemaVersion: Int
    public let id: UUID
    public let name: String
    public let scene: SceneSnapshot
    public let graphLayout: GraphLayout
    public init(id: UUID = UUID(), name: String = "Untitled", scene: SceneSnapshot = .init(), graphLayout: GraphLayout = .init()) {
        schemaVersion = Self.currentVersion; self.id = id; self.name = name; self.scene = scene; self.graphLayout = graphLayout
    }
    public func named(_ name: String) -> Self { Self(id: id, name: name, scene: scene, graphLayout: graphLayout) }
    public static func validatedName(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 120, value != ".", value != "..",
              !value.contains("/"), !value.contains(":"), !value.contains("\\"),
              value.rangeOfCharacter(from: .controlCharacters) == nil else { throw ProjectError.invalidName }
        return value
    }
    public func validate() throws {
        guard schemaVersion == Self.currentVersion else { throw ProjectError.unsupportedVersion(schemaVersion) }
        guard try Self.validatedName(name) == name else { throw ProjectError.invalidName }
        try scene.validate()
        try graphLayout.validate()
    }
}

public enum ProjectCodec {
    public static let maximumBytes = 8 * 1024 * 1024
    public static func encode(_ document: ProjectDocument) throws -> Data {
        try document.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }
    public static func decode(_ data: Data) throws -> ProjectDocument {
        guard data.count <= maximumBytes else { throw ProjectError.tooLarge }
        struct Header: Decodable { let schemaVersion: Int }
        let decoder = JSONDecoder()
        do {
            let version = try decoder.decode(Header.self, from: data).schemaVersion
            if version == 1 {
                struct LegacyScene: Decodable { let color: SceneColor; let seed: UInt32 }
                struct LegacyProject: Decodable { let id: UUID; let name: String; let scene: LegacyScene }
                let old = try decoder.decode(LegacyProject.self, from: data)
                guard old.scene.color.isValid else { throw ProjectError.invalidValues }
                let migrated = ProjectDocument(id: old.id, name: old.name, scene: .init(color: old.scene.color, seed: old.scene.seed))
                try migrated.validate()
                return migrated
            }
            if version == 2 || version == 3 {
                struct LegacyScene: Decodable { let source: SourceKind; let parameters: [String: ParameterValue]; let seed: UInt32; let effects: [EffectInstance]? }
                struct LegacyProject: Decodable { let id: UUID; let name: String; let scene: LegacyScene }
                let old = try decoder.decode(LegacyProject.self, from: data)
                guard Set(old.scene.parameters.keys) == Set(SourceRegistry.defaults.keys) else { throw ProjectError.invalidValues }
                var values: [ParameterID: ParameterValue] = [:]
                for (key, value) in old.scene.parameters {
                    guard let id = ParameterID(rawValue: key), SourceRegistry.parameter(id).allows(value) else { throw ProjectError.invalidValues }
                    values[id] = value
                }
                guard version != 3 || old.scene.effects != nil else { throw ProjectError.corrupt }
                let migrated = ProjectDocument(id: old.id, name: old.name, scene: .init(source: old.scene.source, values: values, seed: old.scene.seed, effects: version == 3 ? old.scene.effects! : []))
                try migrated.validate()
                return migrated
            }
            if version == 4 {
                let old = try decoder.decode(ProjectDocument.self, from: data)
                let migrated = ProjectDocument(id: old.id, name: old.name, scene: old.scene.withMappings([]).withSync(.freeRun), graphLayout: old.graphLayout)
                try migrated.validate()
                return migrated
            }
            guard version == ProjectDocument.currentVersion else { throw ProjectError.unsupportedVersion(version) }
            struct CurrentEnvelope: Decodable {
                struct CurrentScene: Decodable { let mappings: [VisualMapping]; let sync: SceneSync }
                let scene: CurrentScene
            }
            _ = try decoder.decode(CurrentEnvelope.self, from: data)
            let document = try decoder.decode(ProjectDocument.self, from: data)
            try document.validate()
            return document
        } catch let error as GraphDiagnostic { throw error }
        catch let error as ProjectError { throw error }
        catch { throw ProjectError.corrupt }
    }
}
