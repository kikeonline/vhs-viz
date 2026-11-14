import Foundation
import MetalKit
import VHSCore
import Observation

/// A render context belongs to one app document or plug-in instance. Surfaces
/// share its immutable frame, device, queue and pipeline; no app singleton.
@MainActor @Observable public final class RenderSession {
    public let renderer: MetalRenderer
    @ObservationIgnored public private(set) var frame: RenderFrame
    public let builds: GraphBuildCoordinator
    @ObservationIgnored private var acceptedScene = SceneSnapshot()
    @ObservationIgnored private var activeGraph: ShaderGraph?
    private let clock: RenderClock
    private let surfaces = NSHashTable<MTKView>.weakObjects()
    public init(fixedTime: TimeInterval? = nil, shaderURL: URL? = nil) throws {
        renderer = try MetalRenderer(shaderURL: shaderURL)
        let compiler = GraphCompiler(device:renderer.device,shaderURL:shaderURL)
        builds = GraphBuildCoordinator { graph in try await compiler.compile(graph) }
        clock = RenderClock(fixedTime: fixedTime)
        frame = RenderFrame(scene: .init(), time: 0)
    }
    public func register(_ surface: MTKView) { surfaces.add(surface) }
    public func unregister(_ surface: MTKView) { surfaces.remove(surface) }
    public func update(_ scene: SceneSnapshot, effective: SceneSnapshot? = nil) {
        if scene.canEditChain {
            builds.cancel(); activeGraph = nil; renderer.installGraph(nil); acceptedScene = scene
        } else {
            builds.request(scene.graph)
            if let program = builds.takeReady(for:scene.graph) {
                renderer.installGraph(program); activeGraph = scene.graph
            }
            if activeGraph == scene.graph { acceptedScene = scene }
        }
        // Only apply values to the accepted base revision. While a new graph
        // builds/fails, retain the previous effective values and keep its clock running.
        let displayed = acceptedScene == scene ? (effective ?? acceptedScene) : frame.scene
        frame = RenderFrame(scene: displayed, time: clock.time)
        for view in surfaces.allObjects where view.window?.isVisible == true && !view.isHiddenOrHasHiddenAncestor {
            view.draw()
        }
    }
}
