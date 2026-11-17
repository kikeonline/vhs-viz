import Testing
import VHSCore
import VHSRenderer

@Test @MainActor func externalBeatClockChangesActualPixelsAndFreeRunKeepsSeconds() throws {
    let session = try RenderSession(fixedTime:1.234)
    let scene = SceneSnapshot(source:.oscillator,seed:17)
    session.update(scene,time:0)
    let first = try session.renderer.readPixels(session.frame,width:32,height:32)
    session.update(scene,time:0.137)
    let moved = try session.renderer.readPixels(session.frame,width:32,height:32)
    #expect(first != moved && session.frame.time == 0.137)
    session.update(scene)
    #expect(session.frame.time == 1.234)
    session.update(scene,time:.infinity)
    #expect(session.frame.time == 1.234)
}
