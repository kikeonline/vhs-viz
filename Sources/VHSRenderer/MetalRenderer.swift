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
    private let inFlight = DispatchSemaphore(value: 3)
    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw RendererError.unavailable
        }
        self.device = device; self.queue = queue
        guard let url = Bundle.module.url(forResource: "Scene", withExtension: "metal", subdirectory: "Shaders") else {
            throw RendererError.shaderMissing
        }
        let library = try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "sceneVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "sceneFragment")
        descriptor.colorAttachments[0].pixelFormat = Self.pixelFormat
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private func encode(_ frame: RenderFrame, to texture: any MTLTexture,
                        command: any MTLCommandBuffer) throws {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { throw RendererError.resourceCreation }
        struct Uniforms { var color: SIMD4<Float>; var time: Float; var seed: UInt32 }
        var uniforms = Uniforms(color: SIMD4(Float(frame.scene.color.red), Float(frame.scene.color.green),
                                            Float(frame.scene.color.blue), 1), time: Float(frame.time), seed: frame.scene.seed)
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    /// Live submission never waits for GPU completion. Saturation drops a frame.
    public func draw(_ frame: RenderFrame, drawable: any CAMetalDrawable) throws {
        guard inFlight.wait(timeout: .now()) == .success else { return }
        guard let command = queue.makeCommandBuffer() else { inFlight.signal(); throw RendererError.resourceCreation }
        do { try encode(frame, to: drawable.texture, command: command) }
        catch { inFlight.signal(); throw error }
        let gate = inFlight
        command.addCompletedHandler { _ in gate.signal() }
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
        try encode(frame, to: texture, command: command)
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
