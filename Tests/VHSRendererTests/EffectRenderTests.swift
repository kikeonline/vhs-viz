import Foundation
import Metal
import Testing
import VHSCore
@testable import VHSRenderer

private func effect(_ kind: EffectKind, _ values: [String: ParameterValue] = [:]) -> EffectInstance {
    let instance = EffectInstance(kind: kind)
    var scene = SceneSnapshot(source: .gradient, effects: [instance])
    for (key,value) in values { scene = SceneReducer.reduce(scene, .setEffectValue(instance.id,key,value)) }
    return scene.effects[0]
}
private func grayGradient(_ effects: [EffectInstance] = []) -> SceneSnapshot {
    .init(source: .gradient, values: [.gradientStart: .color(.init(red: 0,green: 0,blue: 0)), .gradientEnd: .color(.init(red: 1,green: 1,blue: 1))], effects: effects)
}
private func draw(_ renderer: MetalRenderer, _ scene: SceneSnapshot, _ width: Int = 32, _ height: Int = 16) throws -> [UInt8] {
    try renderer.readPixels(.init(scene: scene,time: 2.375),width: width,height: height)
}
private func red(_ p: [UInt8], _ x: Int, _ y: Int = 8, _ width: Int = 32) -> Int { Int(p[(y*width+x)*4+2]) }
private func srgb(_ v: Double) -> Int { Int(((v <= 0.0031308 ? v*12.92 : 1.055*pow(v,1/2.4)-0.055)*255).rounded()) }

@Test func effectUniformLayoutAndAnalyticFixtures() throws {
    #expect(MemoryLayout<EffectUniforms>.stride == 64)
    let renderer = try MetalRenderer()
    let base = try draw(renderer,grayGradient())
    let threshold = try draw(renderer,grayGradient([effect(.threshold)]))
    for x in 0..<32 { #expect(red(threshold,x) == (x<16 ? 0 : 255)) }
    let soft = try draw(renderer,grayGradient([effect(.threshold,["softness":.number(0.5)])]))
    for x in 0..<32 {
        let v = (Double(x)+0.5)/32
        #expect(abs(red(soft,x)-srgb(v*v*(3-2*v))) <= 1)
    }
    let pixel = try draw(renderer,grayGradient([effect(.pixelate,["size":.number(8)])]))
    for x in 0..<32 { #expect(abs(red(pixel,x)-srgb((Double(x/8)*8+4)/32)) <= 1) }
    let tint = effect(.colorize,["high":.color(.init(red:1,green:0,blue:0))])
    let colorized = try draw(renderer,grayGradient([tint]))
    for x in 0..<32 { #expect(abs(red(colorized,x)-red(base,x)) <= 1 && colorized[(8*32+x)*4+1] == 0 && colorized[(8*32+x)*4] == 0) }
    let split = try draw(renderer,grayGradient([effect(.rgbSplit,["x":.number(4)])]))
    for x in 4..<28 {
        let i = (8*32+x)*4
        #expect(abs(Int(split[i+2])-red(base,x+4)) <= 1)
        #expect(abs(Int(split[i])-red(base,x-4)) <= 1)
        #expect(abs(Int(split[i+1])-red(base,x)) <= 1)
    }
    let translated = try draw(renderer,grayGradient([effect(.transform,["x":.number(0.25)])]))
    for x in 0..<32 { #expect(x<4 ? red(translated,x) == 0 : abs(red(translated,x)-red(base,x-4)) <= 1) }
    let rotated = try draw(renderer,grayGradient([effect(.transform,["rotation":.number(90)])]),32,32)
    for y in 0..<32 { #expect(abs(red(rotated,16,y)-srgb((Double(y)+0.5)/32)) <= 1) }
    let scaled = try draw(renderer,grayGradient([effect(.transform,["scale":.number(2)])]))
    for x in 0..<32 { #expect(abs(red(scaled,x)-srgb(((Double(x)+0.5)/32-0.5)/2+0.5)) <= 1) }
    // A constant must remain constant through both blur axes, including clamped edges.
    let constant = SceneSnapshot(source: .solid, values: [.solidRed:.number(0.5)], effects:[effect(.blur)])
    let blurred = try draw(renderer,constant)
    #expect(stride(from:2,to:blurred.count,by:4).allSatisfy { abs(Int(blurred[$0])-srgb(0.5)) <= 1 })
}

@Test func blurSpreadsAndOrderMatters() throws {
    let renderer = try MetalRenderer()
    let blur = effect(.blur,["radius":.number(8)])
    let shape = SceneSnapshot(source:.shape,values:[.shapeKind:.choice("rectangle"),.shapeSize:.number(0.2),.shapeFill:.color(.init(red:1,green:1,blue:1)),.shapeSoftness:.number(0)],effects:[blur])
    let softened = try draw(renderer,shape,64,64)
    let plain = try draw(renderer,SceneReducer.reduce(shape,.bypassEffect(blur.id,true)),64,64)
    #expect(softened != plain)
    #expect((0..<64).contains { x in red(plain,x,32,64) == 0 && red(softened,x,32,64) > 0 })
    #expect(red(softened,32,32,64) < red(plain,32,32,64))
    let threshold = effect(.threshold), smoothing = effect(.blur,["radius":.number(8)])
    let a = grayGradient([threshold,smoothing]), b = SceneReducer.reduce(a,.moveEffect(threshold.id,1))
    #expect(try draw(renderer,a) != draw(renderer,b))
    #expect(try draw(renderer,a) == draw(renderer,a))
    let bypassed = SceneReducer.reduce(SceneReducer.reduce(a,.bypassEffect(threshold.id,true)),.bypassEffect(smoothing.id,true))
    #expect(try draw(renderer,bypassed) == draw(renderer,grayGradient()))
}

@Test func allEffectBoundariesChainsAndPoolReuse() throws {
    let renderer = try MetalRenderer()
    for kind in EffectKind.allCases {
        for parameter in kind.definition.parameters {
            let values: [ParameterValue]
            switch parameter.kind {
            case let .number(range): values = [.number(range.lowerBound),.number(range.upperBound)]
            case .color: values = [.color(.init(red:0,green:0,blue:0)),.color(.init(red:1,green:1,blue:1))]
            default: values = []
            }
            for value in values {
                let scene = grayGradient([effect(kind,[parameter.id:value])])
                let a = try draw(renderer,scene)
                #expect(a == (try draw(renderer,scene)))
                #expect(stride(from:3,to:a.count,by:4).allSatisfy { a[$0] == 255 })
            }
        }
    }
    let chain = grayGradient((0..<16).map { effect(EffectKind.allCases[$0%6]) })
    for i in 0..<30 {
        let width = i%2 == 0 ? 48 : 64
        _ = try draw(renderer,chain,width,32)
        #expect(renderer.resourceMetrics.textures <= 6)
    }
    let allocations = renderer.resourceMetrics.allocations
    for _ in 0..<10 { _ = try draw(renderer,chain,64,32) }
    #expect(renderer.resourceMetrics.allocations == allocations)
    _ = try draw(renderer,chain,48,32)
    let bothSizes = renderer.resourceMetrics.allocations
    for _ in 0..<10 { _ = try draw(renderer,chain,64,32); _ = try draw(renderer,chain,48,32) }
    #expect(renderer.resourceMetrics.allocations == bothSizes)
    #expect(throws: RendererError.self) { try renderer.readPixels(.init(scene:chain,time:0),width:4097,height:1) }
    let pool = FrameResources()
    let device = try #require(MTLCreateSystemDefaultDevice())
    let slots = try (0..<3).map { _ in try #require(pool.checkout()) }
    #expect(pool.checkout() == nil)
    for slot in slots { _ = try pool.textures(slot,device:device,width:32,height:32) }
    #expect(pool.metrics.textures == 6)
    for slot in slots { pool.release(slot) }
    #expect(pool.checkout() != nil)
}

@Test func versionTwoMigrationKeepsSourcePixels() throws {
    let renderer = try MetalRenderer()
    for kind in SourceKind.allCases {
        let original = ProjectDocument(scene: .init(source:kind,seed:987))
        var json = try #require(JSONSerialization.jsonObject(with:ProjectCodec.encode(original)) as? [String:Any])
        var scene = json["scene"] as! [String:Any]
        scene.removeValue(forKey:"effects"); json["scene"] = scene; json["schemaVersion"] = 2
        let migrated = try ProjectCodec.decode(JSONSerialization.data(withJSONObject:json))
        #expect(try draw(renderer,original.scene) == draw(renderer,migrated.scene))
    }
}
