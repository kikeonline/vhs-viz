import Foundation
import Testing
import Metal
import VHSCore
@testable import VHSRenderer

private func link(_ a: GraphNode,_ b: GraphNode,_ port: String) -> GraphEdge { .init(from:.init(a.id),to:.init(b.id,port)) }
private func imageGraph(_ nodes: [GraphNode], _ edges: [GraphEdge], result: GraphNode) -> ShaderGraph {
    let output = GraphNode(kind:.output)
    return .init(nodes:nodes+[output],edges:edges+[link(result,output,"image")])
}
private func srgb(_ v: Double) -> Int { Int(((v <= 0.0031308 ? v*12.92 : 1.055*pow(v,1/2.4)-0.055)*255).rounded()) }
private func execute(_ graph: ShaderGraph, renderer: MetalRenderer, time: Double = 2.375) async throws -> [UInt8] {
    let compiler = GraphCompiler(device:renderer.device)
    let program = try await compiler.compile(graph)
    return try renderer.readPixels(.init(scene:SceneSnapshot().withGraph(graph),time:time),width:32,height:32,graph:program)
}
@Test func branchingImageBlendAndColorMathGPU() async throws {
    let renderer = try MetalRenderer()
    let a = GraphNode(kind:.color,values:["value":.color(.init(red:1,green:0,blue:0))]), b = GraphNode(kind:.color,values:["value":.color(.init(red:0,green:0,blue:1))])
    let amount = GraphNode(kind:.scalar,values:["value":.number(0.25)]), ca = GraphNode(kind:.imageFromColor), cb = GraphNode(kind:.imageFromColor), mix = GraphNode(kind:.imageMix)
    let graph = imageGraph([a,b,amount,ca,cb,mix],[link(a,ca,"color"),link(b,cb,"color"),link(ca,mix,"a"),link(cb,mix,"b"),link(amount,mix,"amount")],result:mix)
    let pixels = try await execute(graph,renderer:renderer)
    #expect(abs(Int(pixels[2])-srgb(0.75)) <= 1 && abs(Int(pixels[0])-srgb(0.25)) <= 1 && pixels[1] == 0)
    #expect(pixels == (try await execute(graph,renderer:renderer)))
    let colorMix = GraphNode(kind:.colorMix), image = GraphNode(kind:.imageFromColor)
    let colors = imageGraph([a,b,amount,colorMix,image],[link(a,colorMix,"a"),link(b,colorMix,"b"),link(amount,colorMix,"amount"),link(colorMix,image,"color")],result:image)
    #expect(pixels == (try await execute(colors,renderer:renderer)))
}
@Test func valueNodesUVTimeSamplingAndConnectedParametersGPU() async throws {
    let renderer = try MetalRenderer()
    let source = GraphNode(kind:.source(.gradient)), uv = GraphNode(kind:.uv), vector = GraphNode(kind:.vector,values:["x":.number(0),"y":.number(0)])
    let sum = GraphNode(kind:.vectorAdd), sampled = GraphNode(kind:.sampleImage), luminance = GraphNode(kind:.luminance)
    let time = GraphNode(kind:.time), sine = GraphNode(kind:.sine), number = GraphNode(kind:.scalar,values:["value":.number(0.5)])
    let add = GraphNode(kind:.scalarAdd), multiply = GraphNode(kind:.scalarMultiply), vectorMultiply = GraphNode(kind:.vectorMultiply)
    let composed = GraphNode(kind:.composeColor), image = GraphNode(kind:.imageFromColor)
    let nodes = [source,uv,vector,sum,sampled,luminance,time,sine,number,add,multiply,vectorMultiply,composed,image]
    let edges = [link(uv,sum,"a"),link(vector,sum,"b"),link(source,sampled,"image"),link(sum,vectorMultiply,"a"),link(uv,vectorMultiply,"b"),link(vectorMultiply,sampled,"uv"),link(sampled,luminance,"color"),link(time,sine,"value"),link(sine,add,"a"),link(number,add,"b"),link(add,multiply,"a"),link(number,multiply,"b"),link(multiply,composed,"red"),link(luminance,composed,"green"),link(number,composed,"blue"),link(composed,image,"color")]
    let graph = imageGraph(nodes,edges,result:image)
    let a = try await execute(graph,renderer:renderer,time:0), b = try await execute(graph,renderer:renderer,time:Double.pi/2)
    #expect(abs(Int(a[2])-srgb(0.25)) <= 1 && abs(Int(b[2])-srgb(0.75)) <= 1)
    #expect(Set(stride(from:1,to:a.count,by:4).map { a[$0] }).count > 2)
    #expect(stride(from:3,to:a.count,by:4).allSatisfy { a[$0] == 255 })
    // A value node overrides a registered source input without changing its UUID/key.
    let scalar = GraphNode(kind:.scalar,values:["value":.number(0.9)]), solid = GraphNode(kind:.source(.solid))
    let overridden = imageGraph([scalar,solid],[link(scalar,solid,ParameterID.solidRed.rawValue)],result:solid)
    let overriddenPixels = try await execute(overridden,renderer:renderer)
    #expect(abs(Int(overriddenPixels[2])-srgb(0.9)) <= 1)
}
@Test func compiledSourcesEffectsAndMigrationMatchChainGPU() async throws {
    let renderer = try MetalRenderer(), compiler = GraphCompiler(device:try #require(MTLCreateSystemDefaultDevice()))
    for kind in SourceKind.allCases {
        var scene = SceneSnapshot(source:kind,seed:987)
        for effectKind in EffectKind.allCases { scene = SceneReducer.reduce(scene,.addEffect(.init(kind:effectKind))) }
        let expected = try renderer.readPixels(.init(scene:scene,time:2.375),width:32,height:32)
        let program = try await compiler.compile(scene.graph)
        let actual = try renderer.readPixels(.init(scene:scene,time:2.375),width:32,height:32,graph:program)
        #expect(zip(expected,actual).allSatisfy { abs(Int($0)-Int($1)) <= 2 })
        #expect(program.schedule.textureCount <= 2)
    }
    let plain = SceneSnapshot(source:.noise,seed:42)
    let compiled = try await compiler.compile(plain.graph)
    let old = try renderer.readPixels(.init(scene:plain,time:0),width:32,height:32)
    let new = try renderer.readPixels(.init(scene:plain,time:0),width:32,height:32,graph:compiled)
    #expect(zip(old,new).allSatisfy { abs(Int($0)-Int($1)) <= 1 })
    do { _ = try await compiler.compile(plain.graph,extraSource:"\nThis is invalid Metal;"); Issue.record("Compiler fault accepted") }
    catch let error as GraphDiagnostic { #expect(error.node == plain.graph.nodes[0].id && error.message.contains("compile")) }
}
@Test @MainActor func staleBuildsAndLastValidFrameAreSafe() async throws {
    let renderer = try MetalRenderer(), compiler = GraphCompiler(device:try #require(MTLCreateSystemDefaultDevice()))
    let a = SceneSnapshot(source:.solid).graph, b = SceneSnapshot(source:.gradient).graph
    let pa = try await compiler.compile(a), pb = try await compiler.compile(b)
    #expect(await compiler.ranOnMainThread == false)
    let builds = GraphBuildCoordinator { graph in
        if graph == a { try? await Task.sleep(for:.milliseconds(300)); return pa }
        try? await Task.sleep(for:.milliseconds(10)); return pb
    }
    builds.request(a)
    try await Task.sleep(for:.milliseconds(120))
    builds.request(b)
    try await Task.sleep(for:.milliseconds(150))
    #expect(builds.takeReady(for:b)?.graph == b)
    try await Task.sleep(for:.milliseconds(250))
    #expect(builds.takeReady(for:a) == nil)
    _ = renderer
    let session = try RenderSession(fixedTime:0)
    let color = GraphNode(kind:.color), image = GraphNode(kind:.imageFromColor)
    let graph = imageGraph([color,image],[link(color,image,"color")],result:image)
    let scene = SceneSnapshot().withGraph(graph)
    session.update(scene)
    #expect(session.frame.scene != scene)
    for _ in 0..<100 {
        try await Task.sleep(for:.milliseconds(20)); session.update(scene)
        if session.frame.scene == scene { break }
    }
    #expect(session.frame.scene == scene)
    let incomplete = graph.removing(color.id)
    session.update(scene.withGraph(incomplete))
    try await Task.sleep(for:.milliseconds(200)); session.update(scene.withGraph(incomplete))
    #expect(session.frame.scene == scene)
    if case .failed = session.builds.status {} else { Issue.record("Expected node-specific failure") }
}

@Test func liveMappedGraphValuesUseExistingPipelineGPU() async throws {
    let renderer = try MetalRenderer(), compiler = GraphCompiler(device:try #require(MTLCreateSystemDefaultDevice()))
    // Force graph execution with a scalar driving Red, and an independent numeric Green.
    let scalar = GraphNode(kind:.scalar,values:["value":.number(0.1)])
    let solid = GraphNode(kind:.source(.solid)), blur = GraphNode(kind:.effect(.blur))
    let graph = imageGraph([scalar,solid,blur],[link(scalar,solid,ParameterID.solidRed.rawValue),link(solid,blur,"image")],result:blur)
    let base = SceneSnapshot().withGraph(graph)
    let program = try await compiler.compile(graph)
    var a = VisualMapping(target:.init(node:scalar.id,key:"value")); a.upper = 0.5
    var b = VisualMapping(target:.init(node:solid.id,key:ParameterID.solidGreen.rawValue)); b.source = .peak; b.upper = 0.4
    var c = VisualMapping(target:.init(node:blur.id,key:"radius")); c.upper = 0.1
    let scene = base.withMappings([a,b,c])
    var input = MappingInputs(); input.audio = [.rms:1,.peak:1]
    var engine = MappingEngine()
    let effective = engine.evaluate(scene,inputs:input,deltaTime:1/60)
    let before = try renderer.readPixels(.init(scene:scene,time:0),width:16,height:16,graph:program)
    let after = try renderer.readPixels(.init(scene:effective,time:0),width:16,height:16,graph:program)
    #expect(before != after)
    #expect(abs(Int(after[2])-srgb(0.6)) <= 2)
    #expect(abs(Int(after[1])-srgb(0.48)) <= 2)
    // Compare with a separately compiled effective graph; live updates need no compile.
    let reference = try await compiler.compile(effective.graph)
    #expect(after == (try renderer.readPixels(.init(scene:effective,time:0),width:16,height:16,graph:reference)))
    #expect(scene.graph == graph && program.graph == graph)
    input.audio = [:]
    let released = engine.evaluate(scene,inputs:input,deltaTime:1/60)
    #expect(before == (try renderer.readPixels(.init(scene:released,time:0),width:16,height:16,graph:program)))
}

@Test @MainActor func mappedGraphFramesDoNotRecompileAndFailureKeepsEffectiveValues() async throws {
    let source = GraphNode(kind:.source(.solid)), number = GraphNode(kind:.scalar)
    let graph = imageGraph([number,source],[link(number,source,ParameterID.solidRed.rawValue)],result:source)
    var mapping = VisualMapping(target:.init(node:number.id,key:"value")); mapping.upper = 0.3
    let scene = SceneSnapshot().withGraph(graph).withMappings([mapping])
    let session = try RenderSession(fixedTime:0)
    for _ in 0..<150 {
        session.update(scene)
        if session.frame.scene == scene { break }
        try await Task.sleep(for:.milliseconds(20))
    }
    #expect(session.frame.scene == scene)
    var input = MappingInputs(); input.audio[.rms] = 1
    var engine = MappingEngine()
    let effective = engine.evaluate(scene,inputs:input,deltaTime:1/60)
    session.update(scene,effective:effective)
    #expect(session.frame.scene == effective && session.builds.status == .ready)
    input.audio[.rms] = 0.5
    let next = engine.evaluate(scene,inputs:input,deltaTime:1/60)
    session.update(scene,effective:next)
    #expect(session.frame.scene == next && session.builds.status == .ready)
    let broken = scene.withGraph(graph.removing(source.id))
    session.update(broken,effective:broken)
    #expect(session.frame.scene == next)
    try await Task.sleep(for:.milliseconds(200)); session.update(broken,effective:broken)
    #expect(session.frame.scene == next)
    if case .failed = session.builds.status {} else { Issue.record("Invalid graph should report failure") }
}
