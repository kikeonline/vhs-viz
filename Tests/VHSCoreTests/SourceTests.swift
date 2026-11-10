import Foundation
import Testing
@testable import VHSCore

@Test func sourceRegistryIsCompleteAndTyped() throws {
    #expect(SourceRegistry.sources.map(\.id) == SourceKind.allCases)
    let parameters = SourceRegistry.sources.flatMap(\.parameters)
    #expect(Set(parameters.map(\.id)).count == parameters.count)
    #expect(Set(parameters.map(\.id)) == Set(ParameterID.allCases))
    for parameter in parameters {
        #expect(parameter.allows(parameter.defaultValue), "Invalid default: \(parameter.id)")
        #expect(!parameter.title.isEmpty)
        if case let .choice(options) = parameter.kind {
            #expect(!options.isEmpty && Set(options.map(\.id)).count == options.count)
        }
    }
    for source in SourceKind.allCases { try SceneSnapshot(source: source).validate() }
}

@Test func sourceSwitchKeepsSettingsAndEndsGesture() {
    var history = SceneHistory()
    history.beginEdit(); history.send(.setParameter(.solidRed, 0.9))
    history.send(.selectSource(.gradient))
    #expect(history.past.count == 2)
    history.send(.setValue(.gradientAngle, .number(73)))
    let gradient = history.scene
    history.send(.selectSource(.solid))
    #expect(history.scene.color.red == 0.9)
    history.send(.selectSource(.gradient))
    #expect(history.scene == gradient)
    history.undo(); #expect(history.scene.source == .solid)
    history.redo(); #expect(history.scene == gradient)
    history.undo(); history.undo(); history.undo(); history.undo(); history.undo()
    #expect(history.scene == SceneSnapshot())
}

@Test func parameterBoundsAndTypeValidation() {
    for source in SourceKind.allCases {
        let original = SceneSnapshot(source: source)
        for p in source.definition.parameters {
            switch p.kind {
            case let .number(range), let .integer(range):
                for input in [-Double.infinity, .nan, -1e20, 1e20] {
                    let changed = SceneReducer.reduce(original, .setValue(p.id, .number(input)))
                    #expect(p.allows(changed.value(p.id)))
                    #expect(range.contains(changed.number(p.id)))
                }
                #expect(SceneReducer.reduce(original, .setValue(p.id, .toggle(true))) == original)
            case .color:
                #expect(SceneReducer.reduce(original, .setValue(p.id, .choice("wrong"))) == original)
            case .choice:
                #expect(SceneReducer.reduce(original, .setValue(p.id, .choice("unknown"))) == original)
            case .toggle:
                #expect(SceneReducer.reduce(original, .setValue(p.id, .number(1))) == original)
            }
        }
    }
    let noise = SceneReducer.reduce(.init(source: .noise), .setValue(.seed, .number(4294967295)))
    #expect(noise.seed == UInt32.max)
    #expect(SceneReducer.reduce(noise, .setValue(.seed, .number(12.7))).seed == 13)
    #expect(SceneReducer.reduce(.init(), .setValue(.shapeSize, .number(1))) == SceneSnapshot())
}

@Test(arguments: SourceKind.allCases)
func everySourcePersistsAndEveryValueUndoes(_ source: SourceKind) throws {
    var history = SceneHistory(scene: .init(source: source, seed: 0xfedcba98))
    for p in source.definition.parameters {
        let original = history.scene
        let replacement: ParameterValue
        switch p.kind {
        case let .number(range), let .integer(range): replacement = .number(range.upperBound)
        case .color: replacement = .color(.init(red: 0.1, green: 0.6, blue: 0.3))
        case let .choice(options): replacement = .choice(options.last!.id)
        case .toggle: replacement = .toggle(!history.scene.enabled(p.id))
        }
        history.send(.setValue(p.id, replacement))
        let changed = history.scene
        #expect(changed != original)
        history.undo(); #expect(history.scene == original)
        history.redo(); #expect(history.scene == changed)
    }
    let document = ProjectDocument(name: "Every Source", scene: history.scene)
    #expect(try ProjectCodec.decode(ProjectCodec.encode(document)) == document)
}

@Test func versionOneMigrationPreservesIdentityColorAndSeed() throws {
    let data = Data(#"{"schemaVersion":1,"id":"EA579C18-3A01-4D71-8C52-6266456E86C3","name":"Old Show","scene":{"color":{"red":0.11,"green":0.22,"blue":0.33},"seed":4294967295}}"#.utf8)
    let migrated = try ProjectCodec.decode(data)
    #expect(migrated.schemaVersion == ProjectDocument.currentVersion && migrated.scene.source == .solid)
    #expect(migrated.id.uuidString == "EA579C18-3A01-4D71-8C52-6266456E86C3")
    #expect(migrated.name == "Old Show" && migrated.scene.seed == UInt32.max)
    #expect(migrated.scene.color == SceneColor(red: 0.11, green: 0.22, blue: 0.33))
    #expect(try ProjectCodec.decode(ProjectCodec.encode(migrated)) == migrated)
    #expect(throws: ProjectError.invalidValues) { try ProjectCodec.decode(Data(String(decoding: data, as: UTF8.self).replacingOccurrences(of: "0.11", with: "2").utf8)) }
}

@Test func malformedTypedSourceFilesAreRejected() throws {
    let encoded = try ProjectCodec.encode(.init(scene: .init(source: .gradient)))
    let original = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    func altered(_ key: String, _ value: Any?) throws -> Data {
        var document = original
        var scene = try #require(document["scene"] as? [String: Any])
        var parameters = try #require(scene["parameters"] as? [String: Any])
        parameters[key] = value; scene["parameters"] = parameters; document["scene"] = scene
        return try JSONSerialization.data(withJSONObject: document)
    }
    for (key, bad) in [("source.gradient.style", ["type": "choice", "value": "bogus"] as [String: Any]),
                       ("source.gradient.start", ["type": "color", "value": ["red": 2, "green": 0, "blue": 0]]),
                       ("source.gradient.angle", ["type": "toggle", "value": true]),
                       ("source.shape.size", ["type": "number", "value": -1]),
                       ("unknown", ["type": "number", "value": 1])] {
        #expect(throws: ProjectError.invalidValues) { try ProjectCodec.decode(altered(key, bad)) }
    }
    #expect(throws: ProjectError.invalidValues) { try ProjectCodec.decode(altered("source.gradient.angle", nil)) }
    var bad = original; var scene = try #require(bad["scene"] as? [String: Any]); scene["source"] = "video"; bad["scene"] = scene
    #expect(throws: ProjectError.corrupt) { try ProjectCodec.decode(JSONSerialization.data(withJSONObject: bad)) }
}

@Test func parameterAvailabilityAndPrecisionFollowMetadata() {
    let gradient = SceneSnapshot(source:.gradient)
    let angle = SourceRegistry.parameter(.gradientAngle)
    #expect(angle.enabledWhen?.matches(gradient) == true)
    #expect(angle.enabledWhen?.matches(SceneReducer.reduce(gradient,.setValue(.gradientStyle,.choice("radial")))) == false)
    let shape = SceneSnapshot(source:.shape)
    let width = SourceRegistry.parameter(.shapeWidth)
    #expect(width.fractionDigits == 3 && SourceRegistry.parameter(.shapeSoftness).fractionDigits == 3)
    #expect(width.enabledWhen?.matches(shape) == false)
    #expect(width.enabledWhen?.matches(SceneReducer.reduce(shape,.setValue(.shapeOutline,.toggle(true)))) == true)
    #expect(SourceRegistry.parameter(.noiseSpeed).enabledWhen?.matches(.init(source:.noise)) == false)
    #expect(SourceRegistry.parameter(.oscillatorSpeed).enabledWhen?.matches(.init(source:.oscillator)) == true)
}
