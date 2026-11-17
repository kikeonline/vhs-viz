import Foundation
import Testing
import VHSCore
import VHSRealtime
@testable import VHSHostUI

private final class EditLog { var events: [(UInt32,UInt32)] = [] }
private func recordEdit(_ pointer: UnsafeMutableRawPointer?, _ id: UInt32, _ value: Double, _ phase: UInt32) {
    Unmanaged<EditLog>.fromOpaque(pointer!).takeUnretainedValue().events.append((id,phase))
}

@Test @MainActor func hostAutomationRunsWithoutEditorAndUsesHostGestures() throws {
    let bridge = try #require(vhs_bridge_create())
    defer { vhs_bridge_release(bridge) }
    let runtime = try PluginRuntime(bridge,automaticPolling:false)
    defer { runtime.stop() }
    let log = EditLog()
    vhs_bridge_callback(bridge,Unmanaged.passUnretained(log).toOpaque(),recordEdit)
    defer { vhs_bridge_callback(bridge,nil,nil) }
    let target = GraphParameterTarget(node:ShaderGraph.sourceID,key:ParameterID.solidRed.rawValue)
    runtime.bind(slot:7,to:target)
    #expect(runtime.bindings.first?.parameterID == 0x2007)
    let original = runtime.session.document, history = runtime.session.history.past
    log.events = []
    runtime.beginGraphEdit()
    runtime.sendGraph(.setNodeValue(target.node,target.key,.number(0.8)))
    runtime.sendGraph(.setNodeValue(target.node,target.key,.number(0.6)))
    runtime.endGraphEdit(); runtime.tick()
    #expect(log.events.map { $0.1 } == [0,1,1,2])
    #expect(log.events.allSatisfy { $0.0 == 0x2007 })
    #expect(runtime.render.frame.scene.color.red == 0.6)
    #expect(runtime.session.document == original && runtime.session.history.past == history)
    // Simulate editor-closed host playback: only the preallocated slot bank changes.
    vhs_bridge_set_automation(bridge,7,0.9); runtime.tick()
    #expect(runtime.render.frame.scene.color.red == 0.9 && runtime.output == nil)
    #expect(runtime.session.document == original && runtime.session.history.past == history)
    var bytes = [UInt8](repeating:0,count:Int(VHS_STATE_CAPACITY))
    let count = vhs_bridge_copy_document(bridge,&bytes,UInt32(bytes.count),nil,nil)
    let state = try HostDocumentCodec.decode(Data(bytes.prefix(Int(count))))
    #expect(state.bindings == runtime.bindings && state.project == runtime.session.document)
    vhs_bridge_set(bridge,0,0.2); runtime.tick()
    #expect(runtime.render.frame.scene.color.red == 0.9) // Bound slots take precedence over legacy RGB lanes.
}

@Test @MainActor func hostBindingsSurvivePresetsAndMissingTargetsWithoutRetargeting() async throws {
    let bridge = try #require(vhs_bridge_create())
    defer { vhs_bridge_release(bridge) }
    let runtime = try PluginRuntime(bridge,automaticPolling:false)
    defer { runtime.stop() }
    let target = GraphParameterTarget(node:ShaderGraph.sourceID,key:ParameterID.solidRed.rawValue)
    runtime.bind(slot:2,to:target)
    let binding = try #require(runtime.bindings.first)
    try await runtime.loadPreset(FactoryPresets.all[1])
    #expect(runtime.bindings == [binding] && binding.range(in:runtime.session.history.scene.graph) == nil)
    vhs_bridge_set_automation(bridge,2,1); runtime.tick()
    #expect(runtime.render.frame.scene == runtime.session.history.scene)
    runtime.undoGraph()
    #expect(runtime.bindings == [binding] && binding.range(in:runtime.session.history.scene.graph) != nil)
    #expect(runtime.render.frame.scene.color.red == 1)
}

@Test @MainActor func hostRestoreBeforeEditorAndProjectImportExportStayIndependent() async throws {
    let a = try #require(vhs_bridge_create()), b = try #require(vhs_bridge_create())
    defer { vhs_bridge_release(a); vhs_bridge_release(b) }
    var mapping = VisualMapping(target:.init(node:ShaderGraph.sourceID,key:ParameterID.noiseScale.rawValue))
    mapping.source = .cc; mapping.channel = 3; mapping.number = 74
    let scene = FactoryPresets.all[1].scene.withMappings([mapping]).withSync(.followDAW)
    let binding = HostAutomationBinding(slot:4,target:mapping.target)
    let host = HostDocument(project:.init(name:"Saved Song",scene:scene),bindings:[binding])
    let data = try HostDocumentCodec.encode(host)
    #expect(data.withUnsafeBytes { vhs_bridge_store_document(a,$0.bindMemory(to:UInt8.self).baseAddress,UInt32(data.count),1) } > 0)
    vhs_bridge_set_automation(a,4,0.25)
    let first = try PluginRuntime(a,automaticPolling:false), second = try PluginRuntime(b,automaticPolling:false)
    defer { first.stop(); second.stop() }
    #expect(first.session.document == host.project && first.bindings == [binding] && first.output == nil)
    #expect(second.bindings.isEmpty && second.session.document != first.session.document)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VHS-host-\(UUID())")
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    defer { try? FileManager.default.removeItem(at:directory) }
    let url = directory.appendingPathComponent("Portable.vhsproject")
    try await first.exportProject(to:url)
    let exported = try ProjectStore().read(from:url)
    #expect(exported.scene.mappings == [mapping] && exported.scene.sync == .followDAW)
    #expect(exported.scene.number(.noiseScale) == 25.75)
    let id = second.session.id
    try await second.importProject(from:url)
    #expect(second.session.id == id && second.session.fileURL == nil)
    #expect(second.session.history.scene == exported.scene && second.bindings.isEmpty)
    try FileManager.default.removeItem(at:url)
    #expect(first.session.document == host.project && first.bindings == [binding])
}

@Test @MainActor func hostAudioUsesSharedWorkerAndFullMappingSignals() async throws {
    let bridge = try #require(vhs_bridge_create())
    defer { vhs_bridge_release(bridge) }
    let runtime = try PluginRuntime(bridge,automaticPolling:false)
    defer { runtime.stop() }
    var context = VHSHostContext(); context.sampleRate = 48000; context.flags = 1|2|4|8
    context.tempo = 120; context.beats = 8; vhs_bridge_host_context(bridge,context)
    var samples = (0..<4096).map { Float(0.5*sin(2*Double.pi*100*Double($0)/48000)) }
    #expect(samples.withUnsafeMutableBufferPointer { vhs_audio_push_planar(vhs_bridge_audio(bridge),$0.baseAddress,nil,4096,48000,0) } == 1)
    try await runtime.analyzeHostAudio()
    #expect(runtime.audioSignals.ready && abs(runtime.audioSignals.rms-0.3535) < 0.015)
    #expect(runtime.audioSignals.low > 0.3 && runtime.audioSignals.mid < 0.02)
    var m = VisualMapping(target:.init(node:ShaderGraph.sourceID,key:ParameterID.solidRed.rawValue))
    m.upper = 0.5; m.source = .low
    runtime.sendGraph(.setMappings([m])); runtime.sendGraph(.setSync(.followDAW))
    let document = runtime.session.document, history = runtime.session.history.past
    runtime.tick()
    #expect(runtime.render.frame.scene.color.red > 0.39 && runtime.render.frame.time == 8)
    #expect(runtime.session.document == document && runtime.session.history.past == history)
    context.beats = 3; context.flags = 1|4|8; vhs_bridge_host_context(bridge,context); runtime.tick()
    #expect(runtime.render.frame.time == 3 && runtime.clockStatus.contains("stopped"))
    context.flags = 16; vhs_bridge_host_context(bridge,context); runtime.tick()
    #expect(runtime.render.frame.scene.color == document.scene.color && runtime.render.frame.time == 3)
    #expect(runtime.clockStatus.contains("unavailable"))
}

@Test @MainActor func inactiveHostExpiresNotesAudioAndTimingWithoutChangingSavedState() async throws {
    let bridge = try #require(vhs_bridge_create())
    defer { vhs_bridge_release(bridge) }
    let runtime = try PluginRuntime(bridge,automaticPolling:false)
    defer { runtime.stop() }
    var mapping = VisualMapping(target:.init(node:ShaderGraph.sourceID,key:ParameterID.solidRed.rawValue))
    mapping.source = .velocity; mapping.upper = 0.5
    runtime.sendGraph(.setMappings([mapping])); runtime.sendGraph(.setSync(.followDAW))
    var context = VHSHostContext(); context.flags = 1|2|4|8; context.beats = 10; context.tempo = 120
    vhs_bridge_host_context(bridge,context)
    var note = VHSInput(); note.kind = 1; note.channel = 0; note.number = 60; note.value = 1
    vhs_bridge_push(bridge,note); runtime.tick()
    #expect(runtime.render.frame.scene.color.red == 0.74 && runtime.hostInputAvailable)
    let saved = runtime.session.document, history = runtime.session.history.past
    try await Task.sleep(for:.milliseconds(280)); runtime.tick()
    #expect(runtime.render.frame.scene.color.red == 0.24 && runtime.velocity == 0 && !runtime.hostInputAvailable)
    #expect(runtime.render.frame.time == 10 && runtime.clockStatus.contains("unavailable"))
    #expect(runtime.session.document == saved && runtime.session.history.past == history)
}

@Test @MainActor func exposureAllocatesNeverUsedSlotsAndRetiresLanesExplicitly() throws {
    let bridge = try #require(vhs_bridge_create())
    defer { vhs_bridge_release(bridge) }
    let runtime = try PluginRuntime(bridge,automaticPolling:false)
    defer { runtime.stop() }
    let red = GraphParameterTarget(node:ShaderGraph.sourceID,key:ParameterID.solidRed.rawValue)
    let green = GraphParameterTarget(node:ShaderGraph.sourceID,key:ParameterID.solidGreen.rawValue)
    #expect(runtime.expose(red) == 0 && runtime.expose(red) == 0)
    runtime.bind(slot:0,to:nil)
    #expect(runtime.bindings.first?.enabled == false)
    #expect(runtime.expose(green) == 1)
    #expect(runtime.expose(red) == 0 && runtime.bindings.first(where:{ $0.slot == 0 })?.enabled == true)
    #expect(HostAutomationBinding.capacity == 256 && HostAutomationBinding.firstParameterID+255 == 0x20ff)
    runtime.bindings = (0..<256).map { .init(slot:$0,target:.init(node:UUID(),key:"value"),enabled:false) }
    let reserved = runtime.bindings
    #expect(runtime.expose(red) == nil && runtime.bindings == reserved && runtime.error?.contains("reserved") == true)
}
