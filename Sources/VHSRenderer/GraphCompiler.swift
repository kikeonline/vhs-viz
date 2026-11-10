import Foundation
import Metal
import VHSCore

/// Immutable after construction. Metal pipeline objects are safe for concurrent encoding.
public final class CompiledGraph: @unchecked Sendable {
    public let graph: ShaderGraph
    public let schedule: GraphSchedule
    let pipelines: [any MTLRenderPipelineState]
    init(graph: ShaderGraph, schedule: GraphSchedule, pipelines: [any MTLRenderPipelineState]) {
        self.graph = graph; self.schedule = schedule; self.pipelines = pipelines
    }
    func encode(_ frame: RenderFrame, to output: any MTLTexture, command: any MTLCommandBuffer, textures: [any MTLTexture]) throws {
        struct Uniforms { var resolution: SIMD2<Float>; var time: Float; var seed: UInt32 }
        for (index,pass) in schedule.passes.enumerated() {
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = pass.slot.map { textures[$0] } ?? output
            descriptor.colorAttachments[0].loadAction = .dontCare; descriptor.colorAttachments[0].storeAction = .store
            guard let encoder = command.makeRenderCommandEncoder(descriptor:descriptor) else { throw RendererError.resourceCreation }
            encoder.setRenderPipelineState(pipelines[index])
            for (binding,producer) in pass.inputs.enumerated() {
                guard let slot = schedule.passes[producer].slot else { encoder.endEncoding(); throw RendererError.resourceCreation }
                encoder.setFragmentTexture(textures[slot],index:binding)
            }
            var uniforms = Uniforms(resolution:.init(Float(output.width),Float(output.height)),time:frame.time.isFinite ? Float(min(Double(Float.greatestFiniteMagnitude/4),max(-Double(Float.greatestFiniteMagnitude/4),frame.time))) : 0,seed:frame.scene.seed)
            encoder.setFragmentBytes(&uniforms,length:MemoryLayout<Uniforms>.stride,index:0)
            encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3); encoder.endEncoding()
        }
    }
}

/// Actor executor performs validation, code generation and Metal compilation away
/// from the UI and audio callbacks. No project-provided shader text is evaluated.
public actor GraphCompiler {
    private let device: any MTLDevice
    private(set) var ranOnMainThread = false
    private let shaderURL: URL
    public init(device: any MTLDevice, shaderURL: URL? = nil) {
        self.device = device
        self.shaderURL = shaderURL ?? Bundle.module.url(forResource:"Scene",withExtension:"metal",subdirectory:"Shaders")!
    }
    public func compile(_ graph: ShaderGraph) throws -> CompiledGraph { try compile(graph,extraSource:"") }
    // Internal injection tests the actual Metal compiler failure path, never serialized.
    func compile(_ graph: ShaderGraph, extraSource: String) throws -> CompiledGraph {
        ranOnMainThread = Thread.isMainThread
        let ordered = try GraphValidator.validate(graph)
        let schedule = try GraphSchedule(graph:graph,ordered:ordered)
        let common = try String(contentsOf:shaderURL,encoding:.utf8)
        var pipelines: [any MTLRenderPipelineState] = []
        for pass in schedule.passes {
            try Task.checkCancellation()
            do {
                let shader = try GraphShader(graph:graph,pass:pass).fragment()
                let library = try device.makeLibrary(source:common+"\n"+shader+extraSource,options:nil)
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name:"sceneVertex")
                descriptor.fragmentFunction = library.makeFunction(name:"graphFragment")
                descriptor.colorAttachments[0].pixelFormat = pass.node.kind == .output ? MetalRenderer.pixelFormat : .rgba16Float
                pipelines.append(try device.makeRenderPipelineState(descriptor:descriptor))
            } catch let error as GraphDiagnostic { throw error }
            catch { throw GraphDiagnostic("\(pass.node.kind.title) failed to compile: \(error.localizedDescription)",node:pass.node.id) }
        }
        try Task.checkCancellation()
        return CompiledGraph(graph:graph,schedule:schedule,pipelines:pipelines)
    }
}
