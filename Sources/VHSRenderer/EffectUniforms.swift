import VHSCore

/// Fixed 64-byte layout shared with the Metal effect shader.
struct EffectUniforms {
    var p0 = SIMD4<Float>.zero
    var colorA = SIMD4<Float>.zero
    var colorB = SIMD4<Float>.zero
    var resolution: SIMD2<Float>
    var kind: UInt32 = 0
    var padding: UInt32 = 0
    init(_ effect: EffectInstance, width: Int, height: Int, verticalBlur: Bool = false) {
        resolution = .init(Float(width), Float(height))
        func n(_ key: String) -> Float { Float(effect.number(key)) }
        func c(_ key: String) -> SIMD4<Float> {
            let v = effect.color(key); return .init(Float(v.red), Float(v.green), Float(v.blue), 1)
        }
        switch effect.kind {
        case .transform: p0 = .init(n("x"), n("y"), n("rotation") * .pi / 180, n("scale"))
        case .blur: kind = 1; p0 = .init(n("radius"), verticalBlur ? 0 : 1, verticalBlur ? 1 : 0, 0)
        case .pixelate: kind = 2; p0.x = n("size")
        case .threshold: kind = 3; p0 = .init(n("level"), n("softness"), 0, 0)
        case .colorize: kind = 4; p0.x = n("amount"); colorA = c("low"); colorB = c("high")
        case .rgbSplit: kind = 5; p0 = .init(n("x"), n("y"), 0, 0)
        }
    }
}
