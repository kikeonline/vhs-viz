import AppKit
import Observation
import MetalKit
import VHSCore
import VHSRenderer
import VHSGraphUI

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
    var showsGraph = false
    let inputs = StandaloneInputs()
    let mappingEditor = MappingEditorState()
    @ObservationIgnored private var mappingEngine = MappingEngine()
    @ObservationIgnored private var mappingTime = ContinuousClock.now
    @ObservationIgnored private var midiSequence: UInt64 = 0
    @ObservationIgnored private var feedbackTick = 0
    let graphEditor = GraphEditorState()
    var graphBuildMessage: String { renderSession?.builds.status.message ?? "Renderer unavailable" }
    var graphLayout: GraphLayout { session.graphLayout }
    func setGraphLayout(_ layout: GraphLayout) { guard !files.blocksSceneEditing else { return }; session.setGraphLayout(layout); refreshMenu() }
    private(set) var selectedEffectID: UUID?
    var selectedEffect: EffectInstance? { scene.effects.first { $0.id == selectedEffectID } }
    func selectEffect(_ id: UUID?) {
        endEdit()
        selectedEffectID = scene.effects.first(where: { $0.id == id })?.id
    }
    func addEffect(_ kind: EffectKind) {
        guard !files.blocksSceneEditing, scene.effects.count < EffectRegistry.maximumEffects else { return }
        let effect = EffectInstance(kind: kind)
        send(.addEffect(effect)); selectEffect(effect.id)
    }
    func moveEffect(_ id: UUID, by offset: Int) {
        guard let index = scene.effects.firstIndex(where: { $0.id == id }) else { return }
        send(.moveEffect(id, index + offset))
    }
    func removeEffect(_ id: UUID) { send(.removeEffect(id)) }


    init() {
        do { renderSession = try RenderSession(fixedTime: ProcessInfo.processInfo.environment["APP_SNAPSHOT"] != nil ? 2 : nil) }
        catch { renderSession = nil; errorMessage = error.localizedDescription }
    }
    func start() {
        guard timer == nil else { return }
        inputs.startPolling()
        refreshMenu()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { @Sendable [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    func registerSurface(_ view: MTKView) { renderSession?.register(view) }
    func unregisterSurface(_ view: MTKView) { renderSession?.unregister(view) }
    func tick() {
        let now = ContinuousClock.now
        let elapsed = mappingTime.duration(to:now).components
        mappingTime = now
        if inputs.snapshot.midiSequence != midiSequence {
            midiSequence = inputs.snapshot.midiSequence
            for event in inputs.snapshot.midiEvents where event.kind == .controller || (event.kind == .noteOn && event.value > 0) {
                mappingEditor.accept(channel:event.channel,number:event.number,note:event.kind == .noteOn)
            }
        }
        mappingEditor.inputAvailable = inputs.snapshot.mappingInputs.midiAvailable
        let effective = mappingEngine.evaluate(scene,inputs:inputs.snapshot.mappingInputs,
            deltaTime:Double(elapsed.seconds)+Double(elapsed.attoseconds)/1e18)
        renderSession?.update(scene,effective:effective)
        feedbackTick += 1
        if feedbackTick % 4 == 0 { mappingEditor.feedback = mappingEngine.effective }
    }
    func beginEdit() {
        guard !files.blocksSceneEditing else { return }
        session.beginEdit(); sync()
    }
    func endEdit() { session.endEdit(); sync() }
    func send(_ action: SceneAction) {
        guard !files.blocksSceneEditing else { return }
        mappingEditor.cancel(); session.send(action); sync()
    }
    func undo() {
        guard !files.blocksSceneEditing else { return }
        mappingEditor.cancel(); session.undo(); sync()
    }
    func redo() {
        guard !files.blocksSceneEditing else { return }
        mappingEditor.cancel(); session.redo(); sync()
    }
    func replaceProject(_ document: ProjectDocument, fileURL: URL? = nil) {
        mappingEngine.reset(); mappingEditor.cancel(); mappingEditor.selected = nil
        selectedEffectID = nil
        graphEditor.selection = nil; graphEditor.pendingOutput = nil
        showsGraph = !document.scene.canEditChain
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
    private func sync() {
        if selectedEffectID != nil && selectedEffect == nil { selectedEffectID = nil }
        tick(); refreshMenu()
    }
}
