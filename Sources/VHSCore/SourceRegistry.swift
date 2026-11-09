import Foundation

public enum SourceKind: String, Codable, Sendable, CaseIterable {
    case solid, gradient, noise, oscillator, shape
    public var definition: SourceDefinition { SourceRegistry.sources.first { $0.id == self }! }
}

public enum ParameterID: String, Codable, Sendable, CaseIterable {
    case solidRed = "source.solid.red", solidGreen = "source.solid.green", solidBlue = "source.solid.blue"
    case gradientStyle = "source.gradient.style", gradientStart = "source.gradient.start", gradientEnd = "source.gradient.end"
    case gradientAngle = "source.gradient.angle", gradientX = "source.gradient.x", gradientY = "source.gradient.y", gradientReverse = "source.gradient.reverse"
    case noiseScale = "source.noise.scale", noiseContrast = "source.noise.contrast", noiseStyle = "source.noise.style"
    case noiseLow = "source.noise.low", noiseHigh = "source.noise.high", noiseAnimate = "source.noise.animate", noiseSpeed = "source.noise.speed"
    case seed = "scene.seed"
    case oscillatorWave = "source.oscillator.wave", oscillatorFrequency = "source.oscillator.frequency", oscillatorSpeed = "source.oscillator.speed"
    case oscillatorAngle = "source.oscillator.angle", oscillatorPhase = "source.oscillator.phase", oscillatorAnimate = "source.oscillator.animate"
    case oscillatorForeground = "source.oscillator.foreground", oscillatorBackground = "source.oscillator.background"
    case shapeKind = "source.shape.kind", shapeSize = "source.shape.size", shapeX = "source.shape.x", shapeY = "source.shape.y"
    case shapeRotation = "source.shape.rotation", shapeSoftness = "source.shape.softness", shapeOutline = "source.shape.outline"
    case shapeWidth = "source.shape.width", shapeFill = "source.shape.fill", shapeBackground = "source.shape.background"
    public var title: String { SourceRegistry.parameter(self).title }
}

public enum ParameterValue: Equatable, Sendable, Codable {
    case number(Double), color(SceneColor), choice(String), toggle(Bool)
    private enum Keys: String, CodingKey { case type, value }
    private enum Kind: String, Codable { case number, color, choice, toggle }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .number: self = .number(try c.decode(Double.self, forKey: .value))
        case .color: self = .color(try c.decode(SceneColor.self, forKey: .value))
        case .choice: self = .choice(try c.decode(String.self, forKey: .value))
        case .toggle: self = .toggle(try c.decode(Bool.self, forKey: .value))
        }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case let .number(v): try c.encode(Kind.number, forKey: .type); try c.encode(v, forKey: .value)
        case let .color(v): try c.encode(Kind.color, forKey: .type); try c.encode(v, forKey: .value)
        case let .choice(v): try c.encode(Kind.choice, forKey: .type); try c.encode(v, forKey: .value)
        case let .toggle(v): try c.encode(Kind.toggle, forKey: .type); try c.encode(v, forKey: .value)
        }
    }
}

public struct ParameterOption: Equatable, Sendable {
    public let id: String
    public let title: String
    public init(_ id: String, _ title: String) { self.id = id; self.title = title }
}
public enum ParameterKind: Equatable, Sendable {
    case number(ClosedRange<Double>), integer(ClosedRange<Double>), color, choice([ParameterOption]), toggle
}
public enum ParameterCondition: Sendable {
    case choice(ParameterID, String), toggle(ParameterID, Bool)
    public func matches(_ scene: SceneSnapshot) -> Bool {
        switch self {
        case let .choice(id, value): scene.choice(id) == value
        case let .toggle(id, value): scene.enabled(id) == value
        }
    }
}
public struct ParameterDefinition: Sendable, Identifiable {
    public let id: ParameterID
    public let title: String
    public let kind: ParameterKind
    public let defaultValue: ParameterValue
    public let unit: String
    public let enabledWhen: ParameterCondition?
    public var fractionDigits: Int {
        if case let .number(range) = kind { return range.upperBound <= 0.1 ? 3 : 2 }
        return 0
    }
    public init(id: ParameterID, title: String, kind: ParameterKind, defaultValue: ParameterValue, unit: String, enabledWhen: ParameterCondition? = nil) {
        self.id = id; self.title = title; self.kind = kind; self.defaultValue = defaultValue; self.unit = unit; self.enabledWhen = enabledWhen
    }
    public func allows(_ value: ParameterValue) -> Bool {
        switch (kind, value) {
        case let (.number(range), .number(v)): v.isFinite && range.contains(v)
        case let (.integer(range), .number(v)): v.isFinite && range.contains(v) && v.rounded() == v
        case let (.color, .color(v)): v.isValid
        case let (.choice(options), .choice(v)): options.contains { $0.id == v }
        case (.toggle, .toggle): true
        default: false
        }
    }
    /// UI actions constrain numbers; files are validated strictly without repair.
    public func normalized(_ value: ParameterValue) -> ParameterValue? {
        switch (kind, value) {
        case let (.number(range), .number(v)):
            .number(v.isFinite ? min(range.upperBound, max(range.lowerBound, v)) : range.lowerBound)
        case let (.integer(range), .number(v)):
            .number(v.isFinite ? min(range.upperBound, max(range.lowerBound, v.rounded())) : range.lowerBound)
        default: allows(value) ? value : nil
        }
    }
}
public struct SourceDefinition: Sendable, Identifiable {
    public let id: SourceKind
    public let title: String
    public let summary: String
    public let symbol: String
    public let parameters: [ParameterDefinition]
}

public enum SourceRegistry {
    private static let black = SceneColor(red: 0, green: 0, blue: 0)
    private static let white = SceneColor(red: 1, green: 1, blue: 1)
    private static func number(_ id: ParameterID, _ title: String, _ range: ClosedRange<Double>, _ value: Double, _ unit: String = "", when condition: ParameterCondition? = nil) -> ParameterDefinition {
        .init(id: id, title: title, kind: .number(range), defaultValue: .number(value), unit: unit, enabledWhen: condition)
    }
    private static func color(_ id: ParameterID, _ title: String, _ value: SceneColor) -> ParameterDefinition {
        .init(id: id, title: title, kind: .color, defaultValue: .color(value), unit: "")
    }
    private static func choice(_ id: ParameterID, _ title: String, _ options: [ParameterOption]) -> ParameterDefinition {
        .init(id: id, title: title, kind: .choice(options), defaultValue: .choice(options[0].id), unit: "")
    }
    private static func toggle(_ id: ParameterID, _ title: String, _ value: Bool) -> ParameterDefinition {
        .init(id: id, title: title, kind: .toggle, defaultValue: .toggle(value), unit: "")
    }
    public static let sources: [SourceDefinition] = [
        .init(id: .solid, title: "Solid", summary: "Fill the scene with a single color.", symbol: "square.fill", parameters: [
            number(.solidRed, "Red", 0...1, 0.24), number(.solidGreen, "Green", 0...1, 0.08), number(.solidBlue, "Blue", 0...1, 0.62)
        ]),
        .init(id: .gradient, title: "Gradient", summary: "Blend two colors along a line or from a center.", symbol: "circle.lefthalf.filled", parameters: [
            choice(.gradientStyle, "Style", [.init("linear", "Linear"), .init("radial", "Radial")]),
            color(.gradientStart, "Start color", .initial), color(.gradientEnd, "End color", .init(red: 1, green: 0.48, blue: 0.1)),
            number(.gradientAngle, "Angle", -180...180, 0, "°", when: .choice(.gradientStyle, "linear")), number(.gradientX, "Center X", 0...1, 0.5), number(.gradientY, "Center Y", 0...1, 0.5),
            toggle(.gradientReverse, "Reverse", false)
        ]),
        .init(id: .noise, title: "Noise", summary: "Build a repeatable pattern from a saved seed.", symbol: "sparkles", parameters: [
            choice(.noiseStyle, "Style", [.init("smooth", "Smooth"), .init("cells", "Cells")]),
            number(.noiseScale, "Scale", 1...100, 16), number(.noiseContrast, "Contrast", 0...2, 1),
            color(.noiseLow, "Low color", black), color(.noiseHigh, "High color", white),
            .init(id: .seed, title: "Seed", kind: .integer(0...Double(UInt32.max)), defaultValue: .number(1), unit: ""),
            toggle(.noiseAnimate, "Animate", false), number(.noiseSpeed, "Speed", 0...2, 0.25, "cells/s", when: .toggle(.noiseAnimate, true))
        ]),
        .init(id: .oscillator, title: "Oscillator", summary: "Move repeating waves with the shared clock.", symbol: "waveform", parameters: [
            choice(.oscillatorWave, "Waveform", [.init("sine", "Sine"), .init("triangle", "Triangle"), .init("square", "Square")]),
            number(.oscillatorFrequency, "Cycles", 1...20, 5), number(.oscillatorSpeed, "Speed", -2...2, 0.25, "cycles/s", when: .toggle(.oscillatorAnimate, true)),
            number(.oscillatorAngle, "Angle", -180...180, 0, "°"), number(.oscillatorPhase, "Phase", 0...1, 0),
            color(.oscillatorForeground, "Foreground", .initial), color(.oscillatorBackground, "Background", black),
            toggle(.oscillatorAnimate, "Animate", true)
        ]),
        .init(id: .shape, title: "Shape", summary: "Place a filled or outlined geometric shape.", symbol: "circle.square", parameters: [
            choice(.shapeKind, "Shape", [.init("circle", "Circle"), .init("rectangle", "Rectangle"), .init("triangle", "Triangle")]),
            color(.shapeFill, "Fill color", .initial), color(.shapeBackground, "Background", black),
            number(.shapeSize, "Size", 0.05...1, 0.6), number(.shapeX, "Position X", 0...1, 0.5), number(.shapeY, "Position Y", 0...1, 0.5),
            number(.shapeRotation, "Rotation", -180...180, 0, "°"), number(.shapeSoftness, "Softness", 0...0.1, 0.005),
            toggle(.shapeOutline, "Outline", false), number(.shapeWidth, "Outline width", 0.002...0.1, 0.02, when: .toggle(.shapeOutline, true))
        ])
    ]
    public static let parameters: [ParameterID: ParameterDefinition] = Dictionary(uniqueKeysWithValues: sources.flatMap(\.parameters).map { ($0.id, $0) })
    public static func parameter(_ id: ParameterID) -> ParameterDefinition { parameters[id]! }
    public static let defaults: [String: ParameterValue] = Dictionary(uniqueKeysWithValues: parameters.values.filter { $0.id != .seed }.map { ($0.id.rawValue, $0.defaultValue) })
}
