import Foundation
import Testing
import VHSCore
@testable import VHSRenderer

@Test func factoryPresetsCompileAndRenderDeterministically() async throws {
    let renderer = try MetalRenderer(), compiler = GraphCompiler(device:renderer.device)
    for preset in FactoryPresets.all {
        let decoded = try PresetCodec.decode(PresetCodec.encode(preset))
        let program = try await compiler.compile(decoded.scene.graph)
        let frame = RenderFrame(scene:decoded.scene,time:2)
        let pixels = try renderer.readPixels(frame,width:32,height:32,graph:program)
        #expect(pixels == (try renderer.readPixels(frame,width:32,height:32,graph:program)))
        #expect(stride(from:3,to:pixels.count,by:4).allSatisfy { pixels[$0] == 255 })
    }
    #expect(await compiler.ranOnMainThread == false)
}

@Test @MainActor func presetCompilerFailurePreservesActualFrameAndHistory() async throws {
    let renderer = try MetalRenderer(), compiler = GraphCompiler(device:renderer.device)
    let render = try RenderSession(fixedTime:2)
    var history = SceneHistory(scene:.init(seed:49))
    render.update(history.scene)
    let previous = render.frame
    do {
        let scene = try await PresetCodec.prepare(FactoryPresets.all[2]) { graph in
            _ = try await compiler.compile(graph,extraSource:"\nInvalid Metal shader text;")
        }
        history.send(.replaceScene(scene)); render.update(scene)
        Issue.record("Invalid shader unexpectedly compiled")
    } catch is GraphDiagnostic {}
    #expect(render.frame == previous && !history.canUndo)
    let prepared = try await render.preparePreset(FactoryPresets.all[2])
    history.send(.replaceScene(prepared)); render.update(prepared)
    for _ in 0..<150 {
        try await Task.sleep(for:.milliseconds(20)); render.update(prepared)
        if render.frame.scene == prepared { break }
    }
    #expect(render.frame.scene == prepared)
    history.undo(); render.update(history.scene)
    #expect(render.frame.scene == previous.scene)
}
