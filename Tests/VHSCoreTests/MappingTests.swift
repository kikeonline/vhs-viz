import Foundation
import Testing
@testable import VHSCore

private let redTarget = GraphParameterTarget(node:ShaderGraph.sourceID,key:ParameterID.solidRed.rawValue)
private func mapped(_ configure: (inout VisualMapping) -> Void = { _ in }) -> SceneSnapshot {
    var m = VisualMapping(target:redTarget); configure(&m)
    return SceneSnapshot(color:.init(red:0.2,green:0.3,blue:0.4)).withMappings([m])
}
@Test func mappingContributionsPreserveBaseAndAreOrderIndependent() {
    var scene = mapped { $0.upper = 0.4 }
    var midi = VisualMapping(target:redTarget); midi.source = .cc; midi.number = 74; midi.upper = 0.2
    scene = scene.withMappings(scene.mappings+[midi])
    var input = MappingInputs(); input.audio[.rms] = 0.5; input.midiAvailable = true; input.controllers[74] = 0.5
    var engine = MappingEngine()
    let result = engine.evaluate(scene,inputs:input,deltaTime:1/60)
    #expect(abs(result.number(.solidRed)-0.5) < 1e-12)
    #expect(scene.number(.solidRed) == 0.2)
    var reverse = MappingEngine()
    #expect(reverse.evaluate(scene.withMappings(scene.mappings.reversed()),inputs:input,deltaTime:1/60).color == result.color)
    input.audio[.rms] = 1; input.controllers[74] = 1
    var large = scene.mappings; large[0].upper = 4; large[1].upper = -4
    #expect(abs(engine.evaluate(scene.withMappings(large),inputs:input,deltaTime:1).number(.solidRed)-0.2) < 1e-12)
    #expect(engine.evaluate(scene,inputs:MappingInputs(),deltaTime:1).color == scene.color)
}
@Test func inversionCurvesRangesAndDisabledMappings() {
    let scene = mapped { $0.lower = -0.1; $0.upper = 0.7; $0.inverted = true; $0.curve = 2 }
    var input = MappingInputs(); input.audio[.rms] = 0.5
    var engine = MappingEngine()
    #expect(abs(engine.evaluate(scene,inputs:input,deltaTime:1).number(.solidRed)-0.3) < 1e-12)
    var m = scene.mappings[0]; m.enabled = false
    #expect(engine.evaluate(scene.withMappings([m]),inputs:input,deltaTime:1).color == scene.color)
    input.audio[.rms] = .nan
    #expect(engine.evaluate(scene,inputs:input,deltaTime:1).color == scene.color)
}
@Test func smoothingIsFrameRateIndependentAndReleases() {
    let scene = mapped { $0.upper = 0.5; $0.smoothing = 0.4 }
    var input = MappingInputs(); input.audio[.rms] = 1
    var a = MappingEngine(), b = MappingEngine()
    var x = scene, y = scene
    for _ in 0..<60 { x = a.evaluate(scene,inputs:input,deltaTime:1/60) }
    for _ in 0..<144 { y = b.evaluate(scene,inputs:input,deltaTime:1/144) }
    #expect(abs(x.number(.solidRed)-y.number(.solidRed)) < 1e-12)
    for _ in 0..<1200 { x = a.evaluate(scene,inputs:MappingInputs(),deltaTime:1/60) }
    #expect(abs(x.number(.solidRed)-scene.number(.solidRed)) < 1e-8)
    var changed = scene.mappings[0]; changed.upper = 0
    #expect(a.evaluate(scene.withMappings([changed]),inputs:input,deltaTime:1).color == scene.color)
}
@Test func notePriorityOmniFilteringAndRelease() {
    var input = MappingInputs(); input.midiAvailable = true
    input.notes = [.init(channel:1,number:60,velocity:0.2),.init(channel:2,number:72,velocity:0.8)]
    var m = VisualMapping(target:redTarget); m.source = .note
    #expect(input.value(for:m) == 72.0/127)
    m.source = .velocity; #expect(input.value(for:m) == 0.8)
    m.channel = 1; #expect(input.value(for:m) == 0.2)
    m.number = 72; #expect(input.value(for:m) == nil)
    m.channel = nil; m.source = .gate; #expect(input.value(for:m) == 1)
    input.notes.removeLast(); #expect(input.value(for:m) == nil)
    m.number = nil; #expect(input.value(for:m) == 1)
    input.midiAvailable = false; #expect(input.value(for:m) == nil)
}
@Test func mappingsSurviveSceneEditsUndoMigrationAndRoundTrip() throws {
    let scene = mapped { $0.source = .cc; $0.number = 74; $0.channel = 3 }
    var session = ProjectSession(document:.init(scene:scene.withSync(.followDAW)))
    session.send(.setParameter(.solidRed,0.5)); #expect(session.history.scene.mappings == scene.mappings)
    session.send(.selectSource(.gradient)); #expect(session.history.scene.mappings == scene.mappings)
    #expect(session.history.scene.mappings[0].unavailable(in:session.history.scene.graph))
    session.undo(); #expect(!session.history.scene.mappings[0].unavailable(in:session.history.scene.graph))
    session.send(.setMappings([])); session.undo(); #expect(session.history.scene.mappings == scene.mappings)
    session.redo(); #expect(session.history.scene.mappings.isEmpty)
    session.undo()
    #expect(try ProjectCodec.decode(ProjectCodec.encode(session.document)) == session.document)
    var old = try #require(JSONSerialization.jsonObject(with:ProjectCodec.encode(.init(scene:scene))) as? [String:Any])
    old["schemaVersion"] = 4
    var oldScene = try #require(old["scene"] as? [String:Any]); oldScene["mappings"] = nil; oldScene["sync"] = nil; old["scene"] = oldScene
    let migrated = try ProjectCodec.decode(JSONSerialization.data(withJSONObject:old))
    #expect(migrated.schemaVersion == 5 && migrated.scene.mappings.isEmpty && migrated.scene.sync == .freeRun)
}
@Test func targetIdentitySurvivesReorderAndDeletionIsUnresolved() {
    let first = EffectInstance(kind:.blur), second = EffectInstance(kind:.blur)
    let base = SceneSnapshot(source:.solid,effects:[first,second])
    let m = VisualMapping(target:.init(node:first.id,key:"radius"))
    let scene = base.withMappings([m])
    let moved = SceneReducer.reduce(scene,.moveEffect(first.id,1))
    #expect(moved.mappings == scene.mappings && !m.unavailable(in:moved.graph))
    let deleted = SceneReducer.reduce(moved,.removeEffect(first.id))
    #expect(deleted.mappings == scene.mappings && m.unavailable(in:deleted.graph))
    var input = MappingInputs(); input.audio[.rms] = 1
    var engine = MappingEngine()
    #expect(engine.evaluate(deleted,inputs:input,deltaTime:1).graph == deleted.graph)
}
@Test func learnConflictsRequireExplicitReplacementAndCancelPreservesOriginal() {
    let a = mapped().mappings[0]
    var b = VisualMapping(target:.init(node:ShaderGraph.sourceID,key:ParameterID.solidBlue.rawValue))
    b.source = .cc; b.channel = 2; b.number = 74
    let candidate = MappingLearn.candidate(a,channel:2,number:74,note:false,omni:true)
    #expect(candidate.channel == nil && candidate.source == .cc)
    #expect(MappingLearn.confirm(candidate,in:[a,b],replaceConflicts:false) == nil)
    #expect(MappingLearn.confirm(candidate,in:[a,b],replaceConflicts:true) == [candidate])
    var different = b; different.channel = 3
    let exact = MappingLearn.candidate(a,channel:2,number:74,note:false,omni:false)
    #expect(!exact.conflicts(with:different))
    let note = MappingLearn.candidate(a,channel:2,number:60,note:true,omni:false)
    #expect(note.source == .gate && note.number == 60)
}
@Test func invalidMappingDefinitionsAreRejectedWithoutDocumentMutation() throws {
    let scene = mapped(), original = scene.mappings[0]
    for mutation: (inout VisualMapping) -> Void in [{$0.channel = 0},{$0.number = 128},{$0.curve = 0},{$0.smoothing = -1},{$0.lower = .nan},{$0.upper = .infinity},{$0.source = .cc}] {
        var m = original; mutation(&m)
        #expect(throws:ProjectError.invalidValues) { try m.validate() }
        #expect(scene.withMappings([m]) == scene)
    }
    #expect(scene.withMappings([original,original]) == scene)
    var payload = try #require(JSONSerialization.jsonObject(with:ProjectCodec.encode(.init(scene:scene))) as? [String:Any])
    var rawScene = try #require(payload["scene"] as? [String:Any])
    var mappings = try #require(rawScene["mappings"] as? [[String:Any]])
    mappings[0]["channel"] = 17; rawScene["mappings"] = mappings; payload["scene"] = rawScene
    #expect(throws:ProjectError.invalidValues) { try ProjectCodec.decode(JSONSerialization.data(withJSONObject:payload)) }
}
