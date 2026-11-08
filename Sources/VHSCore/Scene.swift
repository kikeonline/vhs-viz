import Foundation

public enum ParameterID: String, Codable, Sendable, CaseIterable {
    case solidRed = "source.solid.red"
    case solidGreen = "source.solid.green"
    case solidBlue = "source.solid.blue"
    public var title: String {
        switch self { case .solidRed: "Red"; case .solidGreen: "Green"; case .solidBlue: "Blue" }
    }
}

/// Linear-light RGB in the working space; the renderer encodes sRGB on output.
public struct SceneColor: Equatable, Codable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamp(red); self.green = Self.clamp(green); self.blue = Self.clamp(blue)
    }
    private static func clamp(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0 }
    public subscript(id: ParameterID) -> Double {
        switch id { case .solidRed: red; case .solidGreen: green; case .solidBlue: blue }
    }
    public func replacing(_ id: ParameterID, with value: Double) -> Self {
        Self(red: id == .solidRed ? value : red, green: id == .solidGreen ? value : green,
             blue: id == .solidBlue ? value : blue)
    }
    public static let initial = Self(red: 0.24, green: 0.08, blue: 0.62)
}

public struct SceneSnapshot: Equatable, Codable, Sendable {
    public let color: SceneColor
    public let seed: UInt32
    public init(color: SceneColor = .initial, seed: UInt32 = 1) { self.color = color; self.seed = seed }
}

public enum SceneAction: Sendable {
    case setParameter(ParameterID, Double)
    case setColor(SceneColor)
}

public enum SceneReducer {
    public static func reduce(_ scene: SceneSnapshot, _ action: SceneAction) -> SceneSnapshot {
        let color: SceneColor
        switch action {
        case let .setParameter(id, value): color = scene.color.replacing(id, with: value)
        case let .setColor(value): color = value
        }
        return SceneSnapshot(color: color, seed: scene.seed)
    }
}

/// Value history keeps transient drag updates separate from committed edits.
public struct SceneHistory: Sendable {
    public private(set) var scene: SceneSnapshot
    public private(set) var past: [SceneSnapshot] = []
    public private(set) var future: [SceneSnapshot] = []
    private var editStart: SceneSnapshot?
    public var canUndo: Bool { !past.isEmpty || (editStart != nil && editStart != scene) }
    public var canRedo: Bool { !future.isEmpty && editStart == nil }
    public init(scene: SceneSnapshot = .init()) { self.scene = scene }
    public mutating func beginEdit() { if editStart == nil { editStart = scene } }
    public mutating func send(_ action: SceneAction) {
        let next = SceneReducer.reduce(scene, action)
        guard next != scene else { return }
        if editStart == nil { appendPast(scene); future.removeAll() }
        scene = next
    }
    public mutating func endEdit() {
        guard let start = editStart else { return }
        editStart = nil
        if start != scene { appendPast(start); future.removeAll() }
    }
    public mutating func undo() {
        endEdit()
        guard let previous = past.popLast() else { return }
        future.append(scene); scene = previous
    }
    public mutating func redo() {
        endEdit()
        guard let next = future.popLast() else { return }
        appendPast(scene); scene = next
    }
    private mutating func appendPast(_ snapshot: SceneSnapshot) {
        past.append(snapshot)
        if past.count > 200 { past.removeFirst(past.count - 200) }
    }
}

public struct RenderFrame: Equatable, Sendable {
    public let scene: SceneSnapshot
    public let time: TimeInterval
    public init(scene: SceneSnapshot, time: TimeInterval) { self.scene = scene; self.time = time }
}

public struct RenderClock: Sendable {
    private let origin = ContinuousClock.now
    private let fixedTime: TimeInterval?
    public init(fixedTime: TimeInterval? = nil) { self.fixedTime = fixedTime }
    public var time: TimeInterval {
        if let fixedTime { return fixedTime }
        let duration = origin.duration(to: .now).components
        return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
    }
}
