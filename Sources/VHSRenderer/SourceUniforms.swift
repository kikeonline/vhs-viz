import Foundation
import VHSCore

/// Fixed 112-byte layout mirrored by Scene.metal. No pointers or mutable state cross frames.
struct SourceUniforms {
    var colorA: SIMD4<Float> = .zero
    var colorB: SIMD4<Float> = .zero
    var p0: SIMD4<Float> = .zero
    var p1: SIMD4<Float> = .zero
    var p2: SIMD4<Float> = .zero
    var kind: UInt32 = 0
    var variant: UInt32 = 0
    var seed: UInt32
    var flags: UInt32 = 0
    var resolution: SIMD2<Float>
    var time: Float = 0
    var padding: Float = 0

    init(_ frame: RenderFrame, width: Int, height: Int) {
        let s = frame.scene
        seed = s.seed; resolution = .init(Float(width), Float(height))
        func number(_ id: ParameterID) -> Float { Float(s.number(id)) }
        func angle(_ id: ParameterID) -> Float { number(id) * .pi / 180 }
        func color(_ id: ParameterID) -> SIMD4<Float> { Self.rgb(s.tint(id)) }
        // Fold animation offsets on the CPU while time still has Double precision.
        func offset(_ id: ParameterID) -> Float {
            let value = frame.time * s.number(id)
            return value.isFinite ? Float(value.truncatingRemainder(dividingBy: 4096)) : 0
        }
        switch s.source {
        case .solid: colorA = Self.rgb(s.color)
        case .gradient:
            kind = 1; variant = s.choice(.gradientStyle) == "radial" ? 1 : 0
            colorA = color(.gradientStart); colorB = color(.gradientEnd)
            p0 = .init(angle(.gradientAngle), number(.gradientX), number(.gradientY), s.enabled(.gradientReverse) ? 1 : 0)
        case .noise:
            kind = 2; variant = s.choice(.noiseStyle) == "cells" ? 1 : 0
            colorA = color(.noiseLow); colorB = color(.noiseHigh)
            p0 = .init(number(.noiseScale), number(.noiseContrast), 0, 0)
            time = s.enabled(.noiseAnimate) ? offset(.noiseSpeed) : 0
        case .oscillator:
            kind = 3; variant = s.choice(.oscillatorWave) == "triangle" ? 1 : (s.choice(.oscillatorWave) == "square" ? 2 : 0)
            colorA = color(.oscillatorForeground); colorB = color(.oscillatorBackground)
            p0 = .init(number(.oscillatorFrequency), 0, angle(.oscillatorAngle), number(.oscillatorPhase))
            time = s.enabled(.oscillatorAnimate) ? offset(.oscillatorSpeed) : 0
        case .shape:
            kind = 4; variant = s.choice(.shapeKind) == "rectangle" ? 1 : (s.choice(.shapeKind) == "triangle" ? 2 : 0)
            colorA = color(.shapeFill); colorB = color(.shapeBackground)
            p0 = .init(number(.shapeSize), number(.shapeX), number(.shapeY), angle(.shapeRotation))
            p1 = .init(number(.shapeSoftness), number(.shapeWidth), s.enabled(.shapeOutline) ? 1 : 0, 0)
        }
    }
    private static func rgb(_ c: SceneColor) -> SIMD4<Float> { .init(Float(c.red), Float(c.green), Float(c.blue), 1) }
}
