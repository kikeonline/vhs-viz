import Foundation
import Testing
@testable import VHSCore

@Test func portablePresetRoundTripAndStrictValidation() throws {
    for preset in FactoryPresets.all {
        #expect(try PresetCodec.decode(PresetCodec.encode(preset)) == preset)
    }
    var mapping = VisualMapping(target:.init(node:UUID(),key:"missing"))
    mapping.source = .cc; mapping.channel = 4; mapping.number = 74
    let preset = PresetDocument(name:"Portable",scene:SceneSnapshot(seed:918).withMappings([mapping]).withSync(.followDAW))
    let data = try PresetCodec.encode(preset)
    #expect(try PresetCodec.decode(data) == preset)
    let json = try #require(JSONSerialization.jsonObject(with:data) as? [String:Any])
    #expect(Set(json.keys) == ["format","version","sceneVersion","name","scene"])
    #expect(throws:(any Error).self) { try PresetCodec.decode(Data("{}".utf8)) }
    #expect(throws:(any Error).self) { try PresetCodec.decode(ProjectCodec.encode(.init())) }
    #expect(throws:ProjectError.tooLarge) { try PresetCodec.decode(Data(repeating:32,count:PresetCodec.maximumBytes+1)) }
    for (key,value) in [("version",99),("sceneVersion",99)] {
        var invalid = json; invalid[key] = value
        #expect(throws:(any Error).self) { try PresetCodec.decode(JSONSerialization.data(withJSONObject:invalid)) }
    }
    var wrongType = json; wrongType["version"] = true
    #expect(throws:(any Error).self) { try PresetCodec.decode(JSONSerialization.data(withJSONObject:wrongType)) }
    var malformed = json; malformed["scene"] = ["seed":"wrong"]
    #expect(throws:(any Error).self) { try PresetCodec.decode(JSONSerialization.data(withJSONObject:malformed)) }
    var unknown = json
    var scene = try #require(unknown["scene"] as? [String:Any])
    var graph = try #require(scene["graph"] as? [String:Any])
    graph["version"] = 99; scene["graph"] = graph; unknown["scene"] = scene
    #expect(throws:(any Error).self) { try PresetCodec.decode(JSONSerialization.data(withJSONObject:unknown)) }
}

@Test func presetUsesValidatedProjectMigrations() throws {
    let old: [String:Any] = ["format":"vhs-preset","version":1,"sceneVersion":1,"name":"Legacy",
        "scene":["color":["red":0.2,"green":0.3,"blue":0.8],"seed":47]]
    let preset = try PresetCodec.decode(JSONSerialization.data(withJSONObject:old))
    #expect(preset.scene == SceneSnapshot(color:.init(red:0.2,green:0.3,blue:0.8),seed:47))
    var v4 = try #require(JSONSerialization.jsonObject(with:PresetCodec.encode(FactoryPresets.all[1])) as? [String:Any])
    v4["sceneVersion"] = 4
    var scene = try #require(v4["scene"] as? [String:Any]); scene["mappings"] = nil; scene["sync"] = nil; v4["scene"] = scene
    #expect(try PresetCodec.decode(JSONSerialization.data(withJSONObject:v4)).scene.mappings.isEmpty)
}

@Test func atomicPresetWritesCollisionsAndOrganization() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VHS-presets-\(UUID())")
    defer { try? FileManager.default.removeItem(at:directory) }
    let store = PresetStore(directory:directory)
    let preset = FactoryPresets.all[1].named("Grain")
    try store.save(preset)
    #expect(throws:ProjectError.destinationExists) { try store.save(preset) }
    #expect(throws:ProjectError.destinationExists) { try store.save(preset.named("grain")) }
    enum Fault: Error { case disk }
    #expect(throws:Fault.self) { try store.save(preset.named("Grain"),overwrite:true,beforeCommit:{ throw Fault.disk }) }
    #expect(try store.read("Grain") == preset)
    #expect(try store.list() == ["Grain"])
    #expect(throws:ProjectError.invalidName) { try store.save(preset.named("../escape")) }
    try store.save(preset.named("Copy"))
    #expect(throws:ProjectError.destinationExists) { try store.rename("Copy",to:"Grain") }
    #expect(try store.read("Copy").scene == preset.scene)
    try store.rename("Copy",to:"Renamed")
    try store.delete("Renamed")
    #expect(try store.list() == ["Grain"])
    let export = directory.appendingPathComponent("Portable.vhspreset")
    try store.writeFile(preset,to:export)
    #expect(try store.readFile(export) == preset)
    #expect(throws:ProjectError.destinationExists) { try store.writeFile(preset.named("Other"),to:export) }
    #expect(try store.readFile(export) == preset)
    try store.writeFile(preset.named("Replaced"),to:export,overwrite:true)
    #expect(try store.readFile(export).name == "Replaced")
}

@Test func presetLoadIsOneUndoAndLibraryIndependent() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VHS-preset-recall-\(UUID())")
    defer { try? FileManager.default.removeItem(at:directory) }
    let store = PresetStore(directory:directory)
    let preset = FactoryPresets.all[2]
    try store.save(preset)
    let url = directory.appendingPathComponent("Show.vhsproject")
    var session = ProjectSession(fileURL:url)
    let original = session.document
    session.beginEdit(); session.send(.setParameter(.solidRed,0.9))
    let edited = session.history.scene
    session.send(.replaceScene(try store.read(preset.name).scene))
    #expect(session.history.past.count == 2)
    #expect(session.id == original.id && session.name == original.name && session.fileURL == url && session.isDirty)
    let saved = try ProjectCodec.encode(session.document)
    try store.delete(preset.name)
    #expect(try ProjectCodec.decode(saved).scene == preset.scene)
    session.undo(); #expect(session.history.scene == edited)
    session.redo(); #expect(session.history.scene == preset.scene)
    let broken = preset.scene.withGraph(.init(nodes:[],edges:[]))
    session.send(.replaceScene(broken))
    #expect(session.history.scene == preset.scene && session.history.past.count == 2)
}

@Test func failedPresetPreparationDoesNotCommit() async throws {
    let initial = SceneSnapshot(seed:98)
    var history = SceneHistory(scene:initial)
    enum Fault: Error { case compiler }
    do {
        let prepared = try await PresetCodec.prepare(FactoryPresets.all[2]) { _ in throw Fault.compiler }
        history.send(.replaceScene(prepared))
        Issue.record("Compiler failure was accepted")
    } catch Fault.compiler {}
    #expect(history.scene == initial && !history.canUndo)
}

@Test func unresolvedPresetMappingsKeepIdentityAndStayInactive() throws {
    var mapping = VisualMapping(target:.init(node:UUID(),key:"value"))
    mapping.source = .cc; mapping.number = 12; mapping.channel = 9
    let preset = PresetDocument(name:"Unresolved",scene:SceneSnapshot().withMappings([mapping]))
    let loaded = try PresetCodec.decode(PresetCodec.encode(preset))
    #expect(loaded.scene.mappings == [mapping] && mapping.unavailable(in:loaded.scene.graph))
    var inputs = MappingInputs(); inputs.midiAvailable = true; inputs.controllers[8*128+12] = 1
    var engine = MappingEngine()
    #expect(engine.evaluate(loaded.scene,inputs:inputs,deltaTime:1) == loaded.scene)
}
