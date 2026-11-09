import AppKit
import Observation
import MetalKit
import VHSCore
import VHSRenderer

final class MenuState: ObservableObject {
    static let shared = MenuState()
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var fileCommandsEnabled = true
    @Published private(set) var canSave = true
    func update(canUndo: Bool, canRedo: Bool, fileCommandsEnabled: Bool, canSave: Bool) {
        if self.fileCommandsEnabled != fileCommandsEnabled { self.fileCommandsEnabled = fileCommandsEnabled }
        if self.canSave != canSave { self.canSave = canSave }
        if self.canUndo != canUndo { self.canUndo = canUndo }
        if self.canRedo != canRedo { self.canRedo = canRedo }
    }
}

@Observable final class AppModel {
    private(set) var session = ProjectSession()
    var history: SceneHistory { session.history }
    var document: ProjectDocument { session.document }
    var projectName: String { session.name }
    var fileURL: URL? { session.fileURL }
    var isDirty: Bool { session.isDirty }
    @ObservationIgnored lazy var files = ProjectFileController(model: self)
    var errorMessage: String?
    @ObservationIgnored private let renderSession: RenderSession?
    var renderer: MetalRenderer? { renderSession?.renderer }
    var frame: RenderFrame { renderSession?.frame ?? RenderFrame(scene: scene, time: 0) }
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored lazy var output = OutputWindowController(model: self)
    var scene: SceneSnapshot { history.scene }

    init() {
        do { renderSession = try RenderSession(fixedTime: ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil ? 2 : nil) }
        catch { renderSession = nil; errorMessage = error.localizedDescription }
    }
    func start() {
        guard timer == nil else { return }
        refreshMenu()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { @Sendable [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    func registerSurface(_ view: MTKView) { renderSession?.register(view) }
    func unregisterSurface(_ view: MTKView) { renderSession?.unregister(view) }
    func tick() {
        renderSession?.update(scene)
    }
    func beginEdit() {
        guard !files.blocksSceneEditing else { return }
        session.beginEdit(); sync()
    }
    func endEdit() { session.endEdit(); sync() }
    func send(_ action: SceneAction) {
        guard !files.blocksSceneEditing else { return }
        session.send(action); sync()
    }
    func undo() {
        guard !files.blocksSceneEditing else { return }
        session.undo(); sync()
    }
    func redo() {
        guard !files.blocksSceneEditing else { return }
        session.redo(); sync()
    }
    func replaceProject(_ document: ProjectDocument, fileURL: URL? = nil) {
        session = ProjectSession(document: document, fileURL: fileURL); sync()
    }
    func recordSave(_ document: ProjectDocument, to url: URL) { session.recordSave(document, to: url); sync() }
    func recordRename(name: String, fileURL: URL) { session.recordRename(name: name, fileURL: fileURL); sync() }
    func renameUnsaved(to name: String) throws { try session.renameUnsaved(to: name); sync() }
    func discardChanges() { session.discardChanges(); sync() }
    func refreshMenu() {
        MenuState.shared.update(canUndo: !files.blocksSceneEditing && history.canUndo,
                               canRedo: !files.blocksSceneEditing && history.canRedo,
                               fileCommandsEnabled: files.commandsEnabled,
                               canSave: files.commandsEnabled && session.needsSave)
    }
    private func sync() { tick(); refreshMenu() }
}
