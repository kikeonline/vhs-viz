import Foundation
import Testing
import VHSCore
@testable import VHSRenderer

@Test func solidFixtureUsesSRGBEncodingAndEveryPixel() throws {
    // Real GPU pipeline test: fail rather than silently skip if Metal is unavailable.
    let renderer = try MetalRenderer()
    let scene = SceneSnapshot(color: SceneColor(red: 0.25, green: 0.5, blue: 0.75), seed: 123)
    let frame = RenderFrame(scene: scene, time: RenderClock(fixedTime: 2).time)
    let bytes = try renderer.readPixels(frame, width: 13, height: 7)
    let expected = [225, 188, 137, 255] // sRGB encoded B, G, R, A
    for offset in stride(from: 0, to: bytes.count, by: 4) {
        for channel in 0..<4 { #expect(abs(Int(bytes[offset + channel]) - expected[channel]) <= 1) }
    }
    #expect(try renderer.readPixels(frame, width: 13, height: 7) == bytes)
}

@Test func blackWhiteAndResize() throws {
    let renderer = try MetalRenderer()
    for value in [0.0, 1.0] {
        let frame = RenderFrame(scene: .init(color: .init(red: value, green: value, blue: value)), time: 0)
        for size in [(1, 1), (64, 36), (9, 17)] {
            let bytes = try renderer.readPixels(frame, width: size.0, height: size.1)
            #expect(bytes.count == size.0 * size.1 * 4)
            #expect(bytes.enumerated().allSatisfy { index, byte in byte == (index % 4 == 3 ? 255 : UInt8(value * 255)) })
        }
    }
}
