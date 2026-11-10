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
