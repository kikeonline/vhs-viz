import Foundation

public enum EffectKind: String, Codable, CaseIterable, Sendable {
    case transform, blur, pixelate, threshold, colorize, rgbSplit
    public var definition: EffectDefinition { EffectRegistry.definitions.first { $0.id == self }! }
}

/// Keys are stable within an instance; UUID + key is the future mapping target.
public struct EffectParameter: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let kind: ParameterKind
    public let defaultValue: ParameterValue
    public let unit: String
    public func allows(_ value: ParameterValue) -> Bool {
        switch (kind, value) {
        case let (.number(range), .number(v)): v.isFinite && range.contains(v)
        case let (.color, .color(c)): c.isValid
        default: false
        }
    }
    func normalized(_ value: ParameterValue) -> ParameterValue? {
        if case let .number(range) = kind, case let .number(v) = value {
            return .number(v.isFinite ? min(range.upperBound, max(range.lowerBound, v)) : range.lowerBound)
        }
        return allows(value) ? value : nil
    }
}
public struct EffectDefinition: Identifiable, Sendable {
    public let id: EffectKind
    public let title: String
    public let summary: String
    public let parameters: [EffectParameter]
}
public enum EffectRegistry {
    public static let maximumEffects = 16
    private static func number(_ id: String, _ title: String, _ range: ClosedRange<Double>, _ value: Double, _ unit: String = "") -> EffectParameter {
        .init(id: id, title: title, kind: .number(range), defaultValue: .number(value), unit: unit)
    }
    private static func color(_ id: String, _ title: String, _ color: SceneColor) -> EffectParameter {
        .init(id: id, title: title, kind: .color, defaultValue: .color(color), unit: "")
    }
    public static let definitions: [EffectDefinition] = [
        .init(id: .transform, title: "Transform", summary: "Move, rotate and scale the image. Outside the image is black.", parameters: [
            number("x", "Position X", -1...1, 0), number("y", "Position Y", -1...1, 0),
            number("rotation", "Rotation", -180...180, 0, "°"), number("scale", "Scale", 0.1...4, 1)
        ]),
        .init(id: .blur, title: "Blur", summary: "Soften the image with a Gaussian blur.", parameters: [number("radius", "Radius", 0...32, 8, "px")]),
        .init(id: .pixelate, title: "Pixelate", summary: "Group pixels into square blocks.", parameters: [number("size", "Block size", 1...128, 12, "px")]),
        .init(id: .threshold, title: "Threshold", summary: "Separate dark and bright luminance into black and white.", parameters: [
            number("level", "Level", 0...1, 0.5), number("softness", "Softness", 0...0.5, 0)
        ]),
        .init(id: .colorize, title: "Colorize", summary: "Map luminance between two colors, then mix with the original.", parameters: [
            color("low", "Dark color", .init(red: 0, green: 0, blue: 0)), color("high", "Light color", .initial), number("amount", "Amount", 0...1, 1)
        ]),
        .init(id: .rgbSplit, title: "RGB Split", summary: "Move red and blue in opposite directions around green.", parameters: [
            number("x", "Offset X", -64...64, 8, "px"), number("y", "Offset Y", -64...64, 0, "px")
        ])
    ]
}

public struct EffectInstance: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let kind: EffectKind
    public let bypassed: Bool
    public let parameters: [String: ParameterValue]
    public init(id: UUID = UUID(), kind: EffectKind) {
        self.id = id; self.kind = kind; bypassed = false
        parameters = Dictionary(uniqueKeysWithValues: kind.definition.parameters.map { ($0.id, $0.defaultValue) })
    }
    private init(id: UUID, kind: EffectKind, bypassed: Bool, parameters: [String: ParameterValue]) {
        self.id = id; self.kind = kind; self.bypassed = bypassed; self.parameters = parameters
    }
    public func number(_ key: String) -> Double { if case let .number(v) = parameters[key] { v } else { 0 } }
    public func color(_ key: String) -> SceneColor { if case let .color(v) = parameters[key] { v } else { .initial } }
    public func validate() throws {
        let definitions = kind.definition.parameters
        guard Set(parameters.keys) == Set(definitions.map(\.id)), definitions.allSatisfy({ p in parameters[p.id].map(p.allows) == true }) else {
            throw ProjectError.invalidValues
        }
    }
    func bypassing(_ value: Bool) -> Self { .init(id: id, kind: kind, bypassed: value, parameters: parameters) }
    func replacing(_ key: String, _ value: ParameterValue) -> Self {
        guard let p = kind.definition.parameters.first(where: { $0.id == key }), let value = p.normalized(value) else { return self }
        var values = parameters; values[key] = value
        return .init(id: id, kind: kind, bypassed: bypassed, parameters: values)
    }
}
