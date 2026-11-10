import Foundation
import Metal
import QuartzCore
import VHSCore

public enum RendererError: Error, LocalizedError {
    case unavailable, shaderMissing, resourceCreation, gpu(String)
    public var errorDescription: String? {
        switch self {
        case .unavailable: "Metal is unavailable on this Mac."
        case .shaderMissing: "The scene shader could not be loaded. Rebuild VHS."
        case .resourceCreation: "Unable to allocate rendering resources."
        case let .gpu(message): "Rendering failed: \(message)"
        }
    }
}

/// Shared device, pipeline and queue; each drawable gets its own immutable uniforms.
public final class MetalRenderer {
    public let device: any MTLDevice
    private let queue: any MTLCommandQueue
    private let pipeline: any MTLRenderPipelineState
    public static let pixelFormat = MTLPixelFormat.bgra8Unorm_srgb
    private let sourceIntermediate: any MTLRenderPipelineState
    private let effectIntermediate: any MTLRenderPipelineState
    private let effectOutput: any MTLRenderPipelineState
    private let resources = FrameResources()
    public var resourceMetrics: (textures: Int, allocations: Int) { resources.metrics }
    public init(shaderURL: URL? = nil) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw RendererError.unavailable
        }
        self.device = device; self.queue = queue
        guard let url = shaderURL ?? Bundle.module.url(forResource: "Scene", withExtension: "metal", subdirectory: "Shaders") else {
            throw RendererError.shaderMissing
        }
        let library = try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "sceneVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "sceneFragment")
        descriptor.colorAttachments[0].pixelFormat = Self.pixelFormat
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        sourceIntermediate = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.fragmentFunction = library.makeFunction(name: "effectFragment")
        effectIntermediate = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.colorAttachments[0].pixelFormat = Self.pixelFormat
        effectOutput = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private func encode(_ frame: RenderFrame, to texture: any MTLTexture,
                        command: any MTLCommandBuffer, slot: Int) throws {
        guard texture.width <= 4096, texture.height <= 4096, frame.scene.effects.count <= EffectRegistry.maximumEffects else { throw RendererError.resourceCreation }
        let effects = frame.scene.effects.filter { !$0.bypassed }
        guard !effects.isEmpty else { try encodeSource(frame, to: texture, command: command, state: pipeline); return }
        let scratch = try resources.textures(slot, device: device, width: texture.width, height: texture.height)
        try encodeSource(frame, to: scratch[0], command: command, state: sourceIntermediate)
        var passes: [EffectUniforms] = []
        for effect in effects {
            passes.append(.init(effect, width: texture.width, height: texture.height))
            if effect.kind == .blur { passes.append(.init(effect, width: texture.width, height: texture.height, verticalBlur: true)) }
        }
        var input = scratch[0]
        for (index, value) in passes.enumerated() {
            let last = index == passes.count-1
            let target = last ? texture : scratch[(index+1)%2]
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].loadAction = .dontCare; pass.colorAttachments[0].storeAction = .store
            guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { throw RendererError.resourceCreation }
            var uniforms = value
            encoder.setRenderPipelineState(last ? effectOutput : effectIntermediate)
            encoder.setFragmentTexture(input, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<EffectUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding(); input = target
        }
    }
    private func encodeSource(_ frame: RenderFrame, to texture: any MTLTexture,
                              command: any MTLCommandBuffer, state: any MTLRenderPipelineState) throws {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { throw RendererError.resourceCreation }
        var uniforms = SourceUniforms(frame, width: texture.width, height: texture.height)
        encoder.setRenderPipelineState(state)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SourceUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    /// Live submission never waits for GPU completion. Saturation drops a frame.
    public func draw(_ frame: RenderFrame, drawable: any CAMetalDrawable) throws {
        guard let slot = resources.checkout(width: drawable.texture.width, height: drawable.texture.height) else { return }
        guard let command = queue.makeCommandBuffer() else { resources.release(slot); throw RendererError.resourceCreation }
        do { try encode(frame, to: drawable.texture, command: command, slot: slot) }
        catch { resources.release(slot); throw error }
        let pool = resources
        command.addCompletedHandler { _ in pool.release(slot) }
        command.present(drawable)
        command.commit()
    }

    /// Synchronous GPU readback for fixtures only; never called by live drawing.
    public func readPixels(_ frame: RenderFrame, width: Int, height: Int) throws -> [UInt8] {
        guard width > 0, height > 0, width <= 4096, height <= 4096 else { throw RendererError.resourceCreation }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.pixelFormat,
                            width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget]; descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor), let command = queue.makeCommandBuffer() else {
            throw RendererError.resourceCreation
        }
        guard let slot = resources.checkout(width: width, height: height) else { throw RendererError.resourceCreation }
        defer { resources.release(slot) }
        try encode(frame, to: texture, command: command, slot: slot)
        command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw RendererError.gpu(error.localizedDescription) }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: width * 4,
                             from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        return bytes
    }
}
