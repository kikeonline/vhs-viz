import Foundation
import Testing
@testable import VHSCore

@Test func effectIdentityHistoryAndGesture() throws {
    let a = EffectInstance(kind: .blur), b = EffectInstance(kind: .blur)
    var history = SceneHistory()
    history.send(.addEffect(a)); history.send(.addEffect(b))
    #expect(a.id != b.id && history.scene.effects.count == 2)
    history.beginEdit()
    history.send(.setEffectValue(a.id, "radius", .number(10)))
    history.send(.setEffectValue(a.id, "radius", .number(20)))
    history.endEdit()
    #expect(history.past.count == 3)
    history.undo(); #expect(history.scene.effects[0] == a)
    history.redo(); #expect(history.scene.effects[0].number("radius") == 20)
    let edited = history.scene
    history.send(.moveEffect(a.id, 1))
    #expect(history.scene.effects.map(\.id) == [b.id,a.id])
    history.send(.bypassEffect(a.id, true))
    #expect(history.scene.effects[1].bypassed)
    history.send(.removeEffect(b.id))
    #expect(history.scene.effects.map(\.id) == [a.id])
    history.undo(); history.undo(); history.undo()
    #expect(history.scene == edited)
    let document = ProjectDocument(scene: history.scene)
    #expect(try ProjectCodec.decode(ProjectCodec.encode(document)) == document)
    history.send(.selectSource(.noise))
    #expect(history.scene.effects == edited.effects)
}

@Test func effectLimitsAndInvalidActions() throws {
    var scene = SceneSnapshot()
    for _ in 0..<EffectRegistry.maximumEffects { scene = SceneReducer.reduce(scene, .addEffect(.init(kind: .blur))) }
    let full = scene
    scene = SceneReducer.reduce(scene, .addEffect(.init(kind: .transform)))
    #expect(scene == full)
    scene = SceneReducer.reduce(scene, .addEffect(scene.effects[0]))
    scene = SceneReducer.reduce(scene, .moveEffect(scene.effects[0].id, -1))
    scene = SceneReducer.reduce(scene, .moveEffect(UUID(), 0))
    scene = SceneReducer.reduce(scene, .setEffectValue(scene.effects[0].id, "unknown", .number(0)))
    scene = SceneReducer.reduce(scene, .setEffectValue(scene.effects[0].id, "radius", .color(.initial)))
    #expect(scene == full)
    let clamped = SceneReducer.reduce(scene, .setEffectValue(scene.effects[0].id, "radius", .number(.infinity)))
    #expect(clamped.effects[0].number("radius") == 0)
}

@Test func oldProjectMigrationAndStrictEffectValidation() throws {
    let original = ProjectDocument(scene: .init(source: .noise, values: [.noiseScale: .number(27)], seed: 787))
    var json = try #require(JSONSerialization.jsonObject(with: ProjectCodec.encode(original)) as? [String: Any])
    json["schemaVersion"] = 2
    var oldScene = try #require(json["scene"] as? [String: Any]); oldScene.removeValue(forKey: "effects"); json["scene"] = oldScene
    let migrated = try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json))
    #expect(migrated == original && migrated.scene.effects.isEmpty)
    let valid = ProjectDocument(scene: .init(source: .shape, effects: [.init(kind: .blur)]))
    let data = try ProjectCodec.encode(valid)
    func reject(_ edit: (inout [String: Any]) -> Void) throws {
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var scene = try #require(json["scene"] as? [String: Any]); edit(&scene); json["scene"] = scene
        #expect(throws: (any Error).self) { try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json)) }
    }
    try reject { scene in let effects = scene["effects"] as! [[String: Any]]; scene["effects"] = effects + effects }
    try reject { scene in scene["effects"] = Array(repeating: (scene["effects"] as! [[String: Any]])[0], count: 17) }
    for (key, value) in [("kind", "unknown" as Any), ("id", "bad" as Any), ("parameters", ["radius": ["type": "number", "value": -1]] as Any), ("parameters", [:] as Any)] {
        try reject { scene in var effects = scene["effects"] as! [[String: Any]]; effects[0][key] = value; scene["effects"] = effects }
    }
    // Current schema requires effects; only explicit old-version migration supplies them.
    try reject { $0.removeValue(forKey: "effects") }
}
