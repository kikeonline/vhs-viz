import AppKit
import Observation
import VHSCore
import VHSRenderer

final class MenuState: ObservableObject {
    static let shared = MenuState()
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    func update(canUndo: Bool, canRedo: Bool) {
        if self.canUndo != canUndo { self.canUndo = canUndo }
        if self.canRedo != canRedo { self.canRedo = canRedo }
    }
}

@Observable final class AppModel {
    private(set) var history = SceneHistory()
    var errorMessage: String?
    @ObservationIgnored let renderer: MetalRenderer?
    @ObservationIgnored private let clock: RenderClock
    @ObservationIgnored private(set) var frame: RenderFrame
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored lazy var output = OutputWindowController(model: self)
    var scene: SceneSnapshot { history.scene }

    init() {
        clock = RenderClock(fixedTime: ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil ? 2 : nil)
        frame = RenderFrame(scene: .init(), time: 0)
        do { renderer = try MetalRenderer() }
        catch { renderer = nil; errorMessage = error.localizedDescription }
    }
    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { @Sendable [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    func tick() { frame = RenderFrame(scene: scene, time: clock.time) }
    func beginEdit() { history.beginEdit(); sync() }
    func endEdit() { history.endEdit(); sync() }
    func send(_ action: SceneAction) { history.send(action); sync() }
    func undo() { history.undo(); sync() }
    func redo() { history.redo(); sync() }
    private func sync() {
        tick(); MenuState.shared.update(canUndo: history.canUndo, canRedo: history.canRedo)
    }
}
