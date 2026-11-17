import Foundation
import Testing
@testable import VHSCore

@Test func stableAutomationSlotsRoundTripAndSurviveGraphEdits() throws {
    let effect = EffectInstance(kind:.blur)
    let scene = SceneSnapshot(source:.noise,effects:[effect])
    let binding = HostAutomationBinding(slot:17,target:.init(node:effect.id,key:effect.kind.definition.parameters[0].id))
    let state = HostDocument(project:.init(name:"Song",scene:scene),bindings:[binding])
    #expect(try HostDocumentCodec.decode(HostDocumentCodec.encode(state)) == state)
    #expect(binding.parameterID == 0x2011)
    #expect(try HostDocumentCodec.decode(ProjectCodec.encode(state.project)).bindings.isEmpty)
    let missing = SceneReducer.reduce(scene,.removeEffect(effect.id))
    #expect(binding.range(in:missing.graph) == nil)
    #expect(HostAutomationBinding.applying([binding],values:[17:1],to:missing) == missing)
    #expect(binding.parameterID == 0x2011 && binding.target.node == effect.id)
    let source = HostAutomationBinding(slot:0,target:.init(node:ShaderGraph.sourceID,key:ParameterID.noiseScale.rawValue))
    let automated = HostAutomationBinding.applying([source],values:[0:0.5],to:scene)
    #expect(automated.number(.noiseScale) == 50.5 && scene.number(.noiseScale) == 16)
    let invalid = HostDocument(project:state.project,bindings:[source,source])
    #expect(throws:(any Error).self) { try HostDocumentCodec.encode(invalid) }
    #expect(throws:(any Error).self) { try HostDocumentCodec.encode(.init(project:state.project,bindings:[.init(slot:256,target:source.target)])) }
}

@Test func malformedHostStatePreservesVersionAndCapacityContract() throws {
    #expect(throws:(any Error).self) { try HostDocumentCodec.decode(Data("{}".utf8)) }
    #expect(throws:ProjectError.tooLarge) { try HostDocumentCodec.decode(Data(repeating:0,count:HostDocumentCodec.maximumBytes+1)) }
    var json = try #require(JSONSerialization.jsonObject(with:HostDocumentCodec.encode(.init())) as? [String:Any])
    json["version"] = 99
    #expect(throws:ProjectError.unsupportedVersion(99)) { try HostDocumentCodec.decode(JSONSerialization.data(withJSONObject:json)) }
    json["version"] = 1; json["bindings"] = [["slot":false]]
    #expect(throws:(any Error).self) { try HostDocumentCodec.decode(JSONSerialization.data(withJSONObject:json)) }
}

@Test func followDAWClockHandlesStopsSeeksLoopsTempoAndMissingContext() {
    var clock = HostVisualClock(), transport = HostTransport()
    #expect(clock.time(mode:.freeRun,transport:nil,freeRun:12.75) == 12.75)
    #expect(clock.time(mode:.followDAW,transport:nil,freeRun:90) == 0)
    transport.valid = true; transport.musicalPositionValid = true; transport.beats = 8; transport.playing = true
    #expect(clock.time(mode:.followDAW,transport:transport,freeRun:91) == 8)
    transport.playing = false
    #expect(clock.time(mode:.followDAW,transport:transport,freeRun:92) == 8)
    transport.beats = 4 // seek/loop and a stopped seek adopt the next supplied position
    #expect(clock.time(mode:.followDAW,transport:transport,freeRun:93) == 4)
    #expect(clock.time(mode:.followDAW,transport:nil,freeRun:94) == 4)
    transport.musicalPositionValid = false; transport.tempoValid = true; transport.tempo = 120
    transport.sampleRate = 48_000; transport.samplePosition = 48_000
    #expect(clock.time(mode:.followDAW,transport:transport,freeRun:95) == 2)
    transport.tempo = 60
    #expect(clock.time(mode:.followDAW,transport:transport,freeRun:96) == 1)
    transport.tempo = .nan
    #expect(clock.time(mode:.followDAW,transport:transport,freeRun:97) == 1)
    transport.offline = true
    #expect(clock.time(mode:.followDAW,transport:transport,freeRun:98) == 1)
}
