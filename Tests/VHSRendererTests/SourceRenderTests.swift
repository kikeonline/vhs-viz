import Foundation
import Testing
import VHSCore
@testable import VHSRenderer

private let black = SceneColor(red: 0, green: 0, blue: 0)
private let white = SceneColor(red: 1, green: 1, blue: 1)
private func srgb(_ v: Double) -> Int { Int(((v <= 0.0031308 ? v*12.92 : 1.055*pow(v,1/2.4)-0.055)*255).rounded()) }
private func red(_ pixels: [UInt8], _ x: Int, _ y: Int, _ width: Int) -> Int { Int(pixels[(y*width+x)*4+2]) }

@Test func sourceUniformLayoutMatchesMetal() { #expect(MemoryLayout<SourceUniforms>.stride == 112) }

@Test(arguments: SourceKind.allCases)
func sourceFixturesRepeatAtFixedSeedAndTime(_ source: SourceKind) throws {
    let renderer = try MetalRenderer()
    let scene = SceneSnapshot(source: source, seed: 1234)
    let frame = RenderFrame(scene: scene, time: 2.375)
    let a = try renderer.readPixels(frame, width: 48, height: 32)
    let b = try renderer.readPixels(frame, width: 48, height: 32)
    #expect(a == b)
    #expect(stride(from: 3, to: a.count, by: 4).allSatisfy { a[$0] == 255 })
    if source != .solid { #expect(Set(stride(from: 2, to: a.count, by: 4).map { a[$0] }).count > 2) }
}

@Test func gradientAnalyticSamplesAndVariants() throws {
    let renderer = try MetalRenderer()
    let scene = SceneSnapshot(source: .gradient, values: [.gradientStart: .color(black), .gradientEnd: .color(white)])
    let pixels = try renderer.readPixels(.init(scene: scene, time: 0), width: 32, height: 16)
    for x in 0..<32 { #expect(abs(red(pixels,x,8,32)-srgb((Double(x)+0.5)/32)) <= 1) }
    let reversed = SceneReducer.reduce(scene, .setValue(.gradientReverse, .toggle(true)))
    let r = try renderer.readPixels(.init(scene: reversed,time: 0),width:32,height:16)
    for x in 0..<32 { #expect(abs(red(r,x,8,32)-red(pixels,31-x,8,32)) <= 1) }
    let radial = SceneReducer.reduce(scene,.setValue(.gradientStyle,.choice("radial")))
    let p = try renderer.readPixels(.init(scene: radial,time:0),width:32,height:32)
    #expect(red(p,16,16,32) < 80 && red(p,0,0,32) == 255)
}

@Test func seededNoiseAndAnimation() throws {
    let renderer = try MetalRenderer()
    func draw(_ s: SceneSnapshot, _ t: Double) throws -> [UInt8] { try renderer.readPixels(.init(scene:s,time:t),width:32,height:24) }
    let scene = SceneSnapshot(source: .noise, seed: 1)
    let a = try draw(scene,0)
    #expect(a == (try draw(scene,99)))
    #expect(a != (try draw(SceneSnapshot(source:.noise,seed:2),0)))
    #expect(a != (try draw(SceneReducer.reduce(scene,.setValue(.noiseStyle,.choice("cells"))),0)))
    let animated = SceneReducer.reduce(scene,.setValue(.noiseAnimate,.toggle(true)))
    #expect(a != (try draw(animated,1)))
    // Noise tiles at 4096 cells and wraps its animation offset without a seam.
    #expect(a == (try draw(animated,16384)))
}

@Test func oscillatorWaveformsClockAndFreeze() throws {
    let renderer = try MetalRenderer()
    let scene = SceneSnapshot(source:.oscillator,values:[.oscillatorForeground:.color(white),.oscillatorBackground:.color(black),.oscillatorFrequency:.number(1)])
    func draw(_ s: SceneSnapshot,_ t: Double) throws -> [UInt8] { try renderer.readPixels(.init(scene:s,time:t),width:32,height:16) }
    let a = try draw(scene,0)
    for x in 0..<32 {
        let phase = ((Double(x)+0.5)/32-0.5)*2*Double.pi
        #expect(abs(red(a,x,8,32)-srgb(0.5+0.5*sin(phase))) <= 1)
    }
    #expect(a != (try draw(scene,1)))
    #expect(a == (try draw(scene,4)))
    let frozen = SceneReducer.reduce(scene,.setValue(.oscillatorAnimate,.toggle(false)))
    #expect(a == (try draw(frozen,12345)))
    for waveform in ["triangle","square"] { #expect(a != (try draw(SceneReducer.reduce(scene,.setValue(.oscillatorWave,.choice(waveform))),0))) }
}

@Test func shapesAspectOutlineAndVariants() throws {
    let renderer = try MetalRenderer()
    let scene = SceneSnapshot(source:.shape,values:[.shapeFill:.color(white),.shapeBackground:.color(black),.shapeSoftness:.number(0)])
    func draw(_ s:SceneSnapshot,_ w:Int,_ h:Int) throws -> [UInt8] { try renderer.readPixels(.init(scene:s,time:0),width:w,height:h) }
    let p = try draw(scene,80,40)
    #expect(red(p,40,20,80) == 255 && red(p,0,0,80) == 0)
    let horizontal = (0..<80).filter { red(p,$0,20,80) > 127 }.count
    let vertical = (0..<40).filter { red(p,40,$0,80) > 127 }.count
    #expect(horizontal == vertical && horizontal == 24)
    let outline = try draw(SceneReducer.reduce(scene,.setValue(.shapeOutline,.toggle(true))),80,40)
    #expect(red(outline,40,20,80) == 0 && outline != p)
    for kind in ["rectangle","triangle"] {
        let q = try draw(SceneReducer.reduce(scene,.setValue(.shapeKind,.choice(kind))),80,40)
        #expect(q != p && red(q,40,20,80) == 255 && red(q,0,0,80) == 0)
    }
}

@Test func allParameterExtremesRenderOpaquePixels() throws {
    let renderer = try MetalRenderer()
    for source in SourceKind.allCases {
        let scene = SceneSnapshot(source:source,seed:UInt32.max)
        for p in source.definition.parameters {
            let values: [ParameterValue]
            switch p.kind {
            case let .number(r), let .integer(r): values = [.number(r.lowerBound),.number(r.upperBound)]
            case let .choice(options): values = options.map { .choice($0.id) }
            case .toggle: values = [.toggle(true),.toggle(false)]
            case .color: values = [.color(black),.color(white)]
            }
            for value in values {
                let changed = SceneReducer.reduce(scene,.setValue(p.id,value))
                let pixels = try renderer.readPixels(.init(scene:changed,time:1e12),width:16,height:12)
                #expect(pixels.count == 16*12*4 && stride(from:3,to:pixels.count,by:4).allSatisfy { pixels[$0] == 255 })
            }
        }
    }
}
