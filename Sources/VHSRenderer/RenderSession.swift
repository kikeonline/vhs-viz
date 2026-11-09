import Foundation
import MetalKit
import VHSCore

/// A render context belongs to one app document or plug-in instance. Surfaces
/// share its immutable frame, device, queue and pipeline; no app singleton.
@MainActor public final class RenderSession {
    public let renderer: MetalRenderer
    public private(set) var frame: RenderFrame
    private let clock: RenderClock
    private let surfaces = NSHashTable<MTKView>.weakObjects()
    public init(fixedTime: TimeInterval? = nil, shaderURL: URL? = nil) throws {
        renderer = try MetalRenderer(shaderURL: shaderURL)
        clock = RenderClock(fixedTime: fixedTime)
        frame = RenderFrame(scene: .init(), time: 0)
    }
    public func register(_ surface: MTKView) { surfaces.add(surface) }
    public func unregister(_ surface: MTKView) { surfaces.remove(surface) }
    public func update(_ scene: SceneSnapshot) {
        frame = RenderFrame(scene: scene, time: clock.time)
        for view in surfaces.allObjects where view.window?.isVisible == true && !view.isHiddenOrHasHiddenAncestor {
            view.draw()
        }
    }
}
