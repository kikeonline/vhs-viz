import AppKit
import SwiftUI
import VHSSignal
import MetalKit
import Observation
import VHSCore
import VHSRenderer
import VHSRealtime
import VHSGraphUI
import VHSInput

@Observable final class PluginRuntime: NSObject, NSWindowDelegate {
    let bridge: OpaquePointer
    let render: RenderSession
    var session = ProjectSession(document:.init(name:"Plug-in Scene"))
    let graphEditor = GraphEditorState()
    var showsGraph = true
    let mappingEditor = MappingEditorState()
    let presets = PresetBrowserState()
    var bindings: [HostAutomationBinding] = []
    var hostValues: [Int:Double] = [:]
    var filesBusy = false
    var hostBaseScene: SceneSnapshot { HostAutomationBinding.applying(bindings,values:hostValues,to:session.history.scene) }
    var showsHostControls = false
    var audioSignals = AudioSignals()
    var hostInputAvailable = false
    var hostTransport: HostTransport?
    var clockStatus = "Free Run · seconds"
    @ObservationIgnored private var hostContextRevision: UInt32 = 0
    @ObservationIgnored private var hostClock = HostVisualClock()
    @ObservationIgnored private let freeClock = RenderClock()
    @ObservationIgnored private let audioWorker: HostAudioWorker
    @ObservationIgnored private var audioTask: Task<Void,Never>?
    @ObservationIgnored private var activeAutomationSlot: Int?
    @ObservationIgnored private var graphGesture = false
    @ObservationIgnored private var graphEditStart: ProjectDocument?
    @ObservationIgnored private var mappingEngine = MappingEngine()
    @ObservationIgnored private var mappingMIDI = MIDIState()
    @ObservationIgnored private var mappingTime = ContinuousClock.now
    @ObservationIgnored private var feedbackTick = 0
    @ObservationIgnored private var documentRevision: UInt32 = 0
    @ObservationIgnored private var documentBytes = [UInt8](repeating:0,count:Int(VHS_STATE_CAPACITY))
    @ObservationIgnored private var pendingDocument: Data?
    @ObservationIgnored private var pendingNotification = false
    var red = 0.24
    var green = 0.08
    var blue = 0.62
    var peak = 0.0
    var velocity = 0.0
    var cc = 0.0
    var tempo = 0.0
    var playing = false
    var dropped: UInt32 = 0
    var error: String?
    @ObservationIgnored var output: NSWindow?
    @ObservationIgnored var timer: Timer?
    @ObservationIgnored var lastBlock = ContinuousClock.now
    init(_ bridge: OpaquePointer, shaderURL: URL? = nil, automaticPolling: Bool = true) throws {
        self.bridge = bridge
        audioWorker = try HostAudioWorker(bridgeAddress:UInt(bitPattern:bridge))
        render = try RenderSession(shaderURL: shaderURL)
        vhs_bridge_retain(bridge)
        super.init()
        if automaticPolling {
        timer = Timer(timeInterval: 1.0 / 60, repeats: true) { @Sendable [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        let worker = audioWorker
        audioTask = Task { [weak self] in
            while !Task.isCancelled {
                if let signals = try? await worker.drain() { self?.audioSignals = signals }
                do { try await Task.sleep(for:.milliseconds(16)) } catch { break }
            }
        }
        }
        tick()
    }
    func stop() {
        finishAutomationGesture()
        audioTask?.cancel(); audioTask = nil
        render.builds.cancel()
        timer?.invalidate(); timer = nil
        output?.contentView = nil; output?.close(); output = nil
    }
    isolated deinit { vhs_bridge_release(bridge) }
    func analyzeHostAudio() async throws { audioSignals = try await audioWorker.drain() }
    func tick() {
        receiveDocument()
        var context = VHSHostContext(), revision: UInt32 = 0
        if vhs_bridge_copy_host_context(bridge,&context,&revision) != 0, revision != hostContextRevision {
            hostContextRevision = revision; lastBlock = .now
            var transport = HostTransport()
            transport.beats = context.beats; transport.tempo = context.tempo; transport.sampleRate = context.sampleRate
            transport.samplePosition = context.samplePosition; transport.valid = context.flags & 1 != 0
            transport.playing = context.flags & 2 != 0; transport.tempoValid = context.flags & 4 != 0
            transport.musicalPositionValid = context.flags & 8 != 0; transport.offline = context.flags & 16 != 0
            hostTransport = transport
        }
        red = vhs_bridge_get(bridge, 0); green = vhs_bridge_get(bridge, 1); blue = vhs_bridge_get(bridge, 2)
        cc = vhs_bridge_get(bridge, 3)
        let base = SceneColor(red:red,green:green,blue:blue)
        if session.history.scene.canEditChain && session.history.scene.source == .solid && session.history.scene.color != base {
            session = ProjectSession(document:.init(id:session.id,name:session.name,scene:SceneReducer.reduce(session.history.scene,.setColor(base)),graphLayout:session.graphLayout))
            queueDocument(notify:false)
        }
        var event = VHSInput()
        let before = vhs_bridge_dropped(bridge)
        for _ in 0..<256 {
            guard vhs_bridge_pop(bridge, &event) != 0 else { break }
            if event.kind == 1 || event.kind == 2 || event.kind == 3 {
                let kind: MIDIEvent.Kind = event.kind == 3 ? .controller : (event.kind == 1 && event.value > 0 ? .noteOn : .noteOff)
                let accepted = mappingMIDI.apply(.init(kind:kind,channel:Int(event.channel)+1,number:Int(event.number),value:event.value))
                if accepted && (kind == .controller || kind == .noteOn) { mappingEditor.accept(channel:Int(event.channel)+1,number:Int(event.number),note:kind == .noteOn) }
            }
            if event.kind == 4 { mappingMIDI.reset() }
            switch event.kind {
            case 0:
                peak = event.value; tempo = event.flags & 4 != 0 ? event.tempo : 0
                playing = event.flags & 2 != 0; lastBlock = .now
            case 1, 2: break // Shared MIDI state owns note lifetime.
            case 3: break // Controller state and learn use the shared MIDI/mapping path above.
            case 4: peak = 0
            default: break
            }
        }
        dropped = vhs_bridge_dropped(bridge)
        // Overflow invalidates held-note state, including retained queued note-ons.
        if dropped != before || dropped != lastDropped || lastBlock.duration(to: .now) > .milliseconds(250) {
            peak = 0; playing = false; mappingMIDI.reset()
        }
        lastDropped = dropped
        let scene = session.history.scene
        let now = ContinuousClock.now
        let elapsed = mappingTime.duration(to:now).components; mappingTime = now
        var input = mappingMIDI.mappingInputs(available:lastBlock.duration(to:now) <= .milliseconds(250))
        velocity = input.notes.map(\.velocity).max() ?? 0
        let available = lastBlock.duration(to:now) <= .milliseconds(250) && hostTransport?.offline != true
        hostInputAvailable = available && hostTransport != nil
        if available {
            input.audio[.peak] = peak
            if audioSignals.ready {
                input.audio[.rms] = audioSignals.rms; input.audio[.peak] = audioSignals.peak
                input.audio[.low] = audioSignals.low; input.audio[.mid] = audioSignals.mid
                input.audio[.high] = audioSignals.high; input.audio[.transient] = audioSignals.transient
            }
        } else { input = MappingInputs(); mappingMIDI.reset(); peak = 0; velocity = 0; cc = 0; playing = false }
        var automation: [Int:Double] = [:]
        for binding in bindings { automation[binding.slot] = vhs_bridge_get_automation(bridge,UInt32(binding.slot)) }
        hostValues = automation
        let automated = HostAutomationBinding.applying(bindings,values:automation,to:scene)
        mappingEditor.inputAvailable = input.midiAvailable
        let effective = mappingEngine.evaluate(automated,inputs:input,deltaTime:Double(elapsed.seconds)+Double(elapsed.attoseconds)/1e18)
        let time = hostClock.time(mode:scene.sync,transport:available ? hostTransport : nil,freeRun:freeClock.time)
        clockStatus = hostClock.status
        render.update(scene,effective:effective,time:time)
        feedbackTick += 1
        if feedbackTick % 4 == 0 { mappingEditor.feedback = mappingEngine.effective }
        publishDocument()
    }
    func loadPreset(_ preset: PresetDocument) async throws {
        let original = session.document
        let prepared = try await render.preparePreset(preset)
        guard session.document == original else { throw PresetError.changed }
        let document = ProjectDocument(id:session.id,name:session.name,scene:prepared,graphLayout:session.graphLayout)
        guard try HostDocumentCodec.encode(.init(project:document,bindings:bindings)).count <= VHS_STATE_CAPACITY else { throw GraphDiagnostic("This preset exceeds the plug-in’s 128 KiB state capacity. The current scene is preserved.") }
        mappingEngine.reset(); mappingMIDI.reset(); mappingEditor.cancel(); mappingEditor.selected = nil
        graphEditor.selection = nil; graphEditor.pendingOutput = nil
        session.send(.replaceScene(prepared)); syncGraphBase(); queueDocument(); tick()
        showsGraph = !prepared.canEditChain || prepared.source != .solid
    }
    func sendGraph(_ action: SceneAction) {
        if case let .setNodeValue(node,key,.number(value)) = action,
           let binding = bindings.first(where: { $0.target == .init(node:node,key:key) }),
           let range = binding.range(in:session.history.scene.graph) {
            let normalized = min(1,max(0,(value-range.lowerBound)/(range.upperBound-range.lowerBound)))
            if activeAutomationSlot != binding.slot {
                finishAutomationGesture()
                activeAutomationSlot = binding.slot
                edit(binding.parameterID,vhs_bridge_get_automation(bridge,UInt32(binding.slot)),0)
            }
            edit(binding.parameterID,normalized,1)
            if !graphGesture { finishAutomationGesture() }
            tick(); return
        }
        mappingEditor.cancel()
        session.send(action)
        syncGraphBase(); queueDocument(); tick()
    }
    func setGraphLayout(_ layout: GraphLayout) { session.setGraphLayout(layout); queueDocument() }
    func beginGraphEdit() { graphGesture = true; graphEditStart = session.document; session.beginEdit() }
    func endGraphEdit() {
        finishAutomationGesture(); graphGesture = false; session.endEdit()
        if graphEditStart != session.document { queueDocument() }
        graphEditStart = nil
    }
    private func finishAutomationGesture() {
        if let slot = activeAutomationSlot {
            edit(HostAutomationBinding.firstParameterID+UInt32(slot),vhs_bridge_get_automation(bridge,UInt32(slot)),2)
        }
        activeAutomationSlot = nil
    }
    @discardableResult func expose(_ target: GraphParameterTarget) -> Int? {
        guard HostAutomationBinding(slot:0,target:target).normalized(in:session.history.scene.graph) != nil else {
            error = "This parameter is unavailable for automation."; return nil
        }
        error = nil
        if let existing = bindings.first(where: { $0.target == target }) {
            if !existing.enabled { bind(slot:existing.slot,to:target) }
            return bindings.contains { $0.slot == existing.slot && $0.enabled } ? existing.slot : nil
        }
        guard let slot = (0..<HostAutomationBinding.capacity).first(where:{ slot in !bindings.contains { $0.slot == slot } }) else {
            error = "All 256 automation slots are reserved. Rebind a slot explicitly to reuse a lane."; return nil
        }
        bind(slot:slot,to:target)
        return bindings.contains { $0.slot == slot && $0.target == target } ? slot : nil
    }
    func bind(slot: Int, to target: GraphParameterTarget?) {
        guard (0..<HostAutomationBinding.capacity).contains(slot) else { return }
        finishAutomationGesture()
        var next = bindings
        var initialValue: Double?
        if let target {
            let binding = HostAutomationBinding(slot:slot,target:target)
            guard let value = binding.normalized(in:session.history.scene.graph),
                  !bindings.contains(where: { $0.slot != slot && $0.target == target }) else { return }
            initialValue = value
            next = bindings.filter { $0.slot != slot } + [binding]
        } else if let previous = bindings.first(where:{ $0.slot == slot }) {
            // Retire instead of freeing: automatic exposure never steals an old DAW lane.
            next = bindings.filter { $0.slot != slot } + [.init(slot:slot,target:previous.target,enabled:false)]
        } else { return }
        do { _ = try HostDocumentCodec.encode(.init(project:session.document,bindings:next)) }
        catch { self.error = error.localizedDescription; return }
        bindings = next
        if let value = initialValue { vhs_bridge_set_automation(bridge,UInt32(slot),value) }
        queueDocument(); tick()
    }
    func undoGraph() { mappingEditor.cancel(); session.undo(); syncGraphBase(); queueDocument(); tick() }
    func redoGraph() { mappingEditor.cancel(); session.redo(); syncGraphBase(); queueDocument(); tick() }
    func syncImportedBase() { syncGraphBase(); mappingEngine.reset(); mappingMIDI.reset() }
    func publishImportedProject() { queueDocument(); tick() }
    private func syncGraphBase() {
        if session.history.scene.canEditChain && session.history.scene.source == .solid {
            let color = session.history.scene.color
            for (index,value) in [color.red,color.green,color.blue].enumerated() { vhs_bridge_set(bridge,UInt32(index),value) }
        }
    }
    private func queueDocument(notify: Bool = true) {
        do {
            let data = try HostDocumentCodec.encode(.init(project:session.document,bindings:bindings))
            guard data.count <= VHS_STATE_CAPACITY else { throw GraphDiagnostic("Plug-in state exceeds 128 KiB. Remove nodes or simplify layout before saving the song; the last valid state is retained.") }
            pendingDocument = data; pendingNotification = pendingNotification || notify; error = nil
            publishDocument()
        }
        catch { self.error = error.localizedDescription }
    }
    @discardableResult private func publishDocument() -> Bool {
        guard let data = pendingDocument else { return false }
        var published: UInt32 = 0
        let result = data.withUnsafeBytes { vhs_bridge_publish_document(bridge,$0.bindMemory(to:UInt8.self).baseAddress,UInt32(data.count),documentRevision,&published) }
        if result >= 0 {
            documentRevision = published; pendingDocument = nil
            if pendingNotification { vhs_bridge_edit(bridge,UInt32.max,0,3); pendingNotification = false }
            return true
        }
        return false
    }
    private func receiveDocument() {
        guard vhs_bridge_document_revision(bridge) != documentRevision else { return }
        var origin: UInt32 = 0, revision: UInt32 = 0
        let count = vhs_bridge_copy_document(bridge,&documentBytes,UInt32(documentBytes.count),&origin,&revision)
        guard count >= 0 else { return }
        documentRevision = revision
        guard origin != 0 else { return }
        do {
            let host = count == 0 ? HostDocument() : try HostDocumentCodec.decode(Data(documentBytes.prefix(Int(count))))
            finishAutomationGesture(); graphGesture = false; graphEditStart = nil
            let document = host.project; bindings = host.bindings
            mappingEngine.reset(); mappingMIDI.reset(); mappingEditor.cancel(); mappingEditor.selected = nil
            session = ProjectSession(document:document); graphEditor.selection = nil; graphEditor.pendingOutput = nil
            pendingDocument = nil; pendingNotification = false; showsGraph = !document.scene.canEditChain
            error = nil
        } catch { self.error = error.localizedDescription }
    }
    @ObservationIgnored private var lastDropped: UInt32 = 0
    func edit(_ id: UInt32, _ value: Double, _ phase: UInt32) {
        // Local bridge state also works in a headless embedding without a controller callback.
        if phase == 1, id >= HostAutomationBinding.firstParameterID, id < HostAutomationBinding.firstParameterID+UInt32(HostAutomationBinding.capacity) {
            vhs_bridge_set_automation(bridge,id-HostAutomationBinding.firstParameterID,value)
        }
        vhs_bridge_edit(bridge, id, value, phase)
    }
    func showOutput() {
        if let output { output.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: Layout.previewWidth, height: Layout.previewHeight),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "VHS Output"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PluginSurface(runtime: self))
        window.delegate = self; output = window
        window.center(); window.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) { output?.contentView = nil; output = nil }
}

struct PluginEditor: View {
    let runtime: PluginRuntime
    var body: some View {
        VStack(alignment:.leading,spacing:Space.sm) {
            HStack(spacing:Space.sm) {
                Button("Presets") { runtime.presets.isPresented.toggle() }
                    .popover(isPresented:Binding(get:{runtime.presets.isPresented},set:{runtime.presets.isPresented = $0})) {
                        PresetBrowser(state:runtime.presets,scene:runtime.hostBaseScene,load:runtime.loadPreset)
                    }
                Button("Mappings") { runtime.mappingEditor.isPresented.toggle() }
                    .help("Map host audio or MIDI to visual parameters")
                    .popover(isPresented:Binding(get:{runtime.mappingEditor.isPresented},set:{runtime.mappingEditor.isPresented = $0})) {
                        MappingEditor(scene:runtime.session.history.scene,state:runtime.mappingEditor,host:true,send:runtime.sendGraph)
                    }
                Button(runtime.showsGraph ? "Solid Controls" : "Nodes") { runtime.showsGraph.toggle() }
                Button("Host Controls") { runtime.showsHostControls.toggle() }
                    .popover(isPresented:Binding(get:{runtime.showsHostControls},set:{runtime.showsHostControls = $0})) {
                        HostControls(runtime:runtime)
                    }
                Menu("Scene") {
                    Button("Undo Scene Change") { runtime.undoGraph() }.disabled(!runtime.session.history.canUndo)
                    Button("Redo Scene Change") { runtime.redoGraph() }.disabled(!runtime.session.history.canRedo)
                    Divider()
                    Button("Import Project…") { Task { await runtime.importProject() } }
                    Button("Export Project…") { Task { await runtime.exportProject() } }
                }
                if runtime.showsGraph {
                    Button("Show Output") { runtime.showOutput() }
                    Text(runtime.render.builds.status.message).font(KitType.meta).foregroundStyle(Ink.secondary).lineLimit(2)
                }
            }
            if runtime.showsGraph {
                if let error = runtime.error { Text(error).font(KitType.meta).foregroundStyle(Ink.secondary).fixedSize(horizontal:false,vertical:true) }
                HStack(alignment:.top,spacing:Space.lg) {
                    PluginSurface(runtime:runtime).frame(width:Layout.graphPreviewWidth,height:Layout.graphPreviewWidth*9/16)
                    Text(runtime.clockStatus + " · Audio bounce does not export visuals.").font(KitType.meta).foregroundStyle(Ink.secondary)
                }
                GraphEditor(graph:runtime.hostBaseScene.graph,layout:runtime.session.graphLayout,seed:runtime.session.history.scene.seed,state:runtime.graphEditor,
                            send:runtime.sendGraph,setLayout:runtime.setGraphLayout,beginEdit:runtime.beginGraphEdit,endEdit:runtime.endGraphEdit)
            } else { probeControls }
        }.padding(Space.margin).signalTheme().disabled(runtime.filesBusy)
    }
    private var probeControls: some View {
        HStack(alignment: .top, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.xl) {
                Text("Solid").font(KitType.section).gridProbe("plugin-source", area: "plugin-controls")
                slider("Red", id: 0, value: runtime.red)
                slider("Green", id: 1, value: runtime.green)
                slider("Blue", id: 2, value: runtime.blue)
                if !runtime.session.history.scene.canEditChain || runtime.session.history.scene.source != .solid {
                    Text("Solid host controls are unavailable for this scene. Open Nodes to edit its parameters.")
                        .font(KitType.meta).foregroundStyle(Ink.secondary).fixedSize(horizontal:false,vertical:true)
                }
                Button("Show Output", systemImage: KitIcon.output.rawValue) { runtime.showOutput() }
                    .help("Open this instance’s visual output")
                    .accessibilityLabel("Show Output")
                Text("Choose Mappings to assign host audio or MIDI.").font(KitType.meta).foregroundStyle(Ink.secondary)
                Text("Peak \(runtime.peak, specifier: "%.3f") · Velocity \(runtime.velocity, specifier: "%.3f") · CC1 \(runtime.cc, specifier: "%.3f")")
                    .monospacedDigit().font(KitType.meta)
                Text(runtime.tempo > 0 ? "\(runtime.tempo.formatted()) BPM · \(runtime.playing ? "Playing" : "Stopped")" : "No host tempo")
                    .foregroundStyle(Ink.secondary)
                if runtime.dropped > 0 { Text("Input overflow: \(runtime.dropped)").foregroundStyle(Ink.secondary) }
                if let error = runtime.error { Text(error).foregroundStyle(Ink.secondary) }
            }.frame(width: Layout.controlWidth)
                .gridArea("plugin-controls", inset: 0)
                .gridProbe("plugin-controls", area: "plugin-editor", edge: nil)
            PluginSurface(runtime: runtime).aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Layout.previewRadius))
                .gridProbe("plugin-preview", area: "plugin-editor", edge: nil)
        }.padding(Space.margin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .gridArea("plugin-editor")
    }
    private func slider(_ title: String, id: UInt32, value: Double) -> some View {
        NumericParameter(title, value: value, range: 0...1, defaultValue: id == 0 ? 0.24 : id == 1 ? 0.08 : 0.62,
                         change: { runtime.edit(id, $0, 1) },
                         exactChange: { runtime.edit(id, $0, 0); runtime.edit(id, $0, 1); runtime.edit(id, $0, 2) },
                         beginEdit: { runtime.edit(id, vhs_bridge_get(runtime.bridge, id), 0) },
                         endEdit: { runtime.edit(id, vhs_bridge_get(runtime.bridge, id), 2) })
            .disabled(!runtime.session.history.scene.canEditChain || runtime.session.history.scene.source != .solid)
            .gridProbe("plugin-\(id)", area: "plugin-controls")
    }
}
struct PluginSurface: NSViewRepresentable {
    let runtime: PluginRuntime
    func makeCoordinator() -> SurfaceDelegate { SurfaceDelegate(runtime) }
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: runtime.render.renderer.device)
        view.colorPixelFormat = MetalRenderer.pixelFormat
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        view.framebufferOnly = true; view.isPaused = true
        view.delegate = context.coordinator
        runtime.render.register(view)
        view.setAccessibilityLabel("Live scene")
        return view
    }
    func updateNSView(_ view: MTKView, context: Context) {}
    static func dismantleNSView(_ view: MTKView, coordinator: SurfaceDelegate) {
        coordinator.runtime.render.unregister(view); view.delegate = nil
    }
    final class SurfaceDelegate: NSObject, MTKViewDelegate {
        let runtime: PluginRuntime
        init(_ runtime: PluginRuntime) { self.runtime = runtime }
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable else { return }
            do { try runtime.render.renderer.draw(runtime.render.frame, drawable: drawable) }
            catch { runtime.error = error.localizedDescription }
        }
    }
}
// Called only from host control/UI operations. Audio never enters Swift.
@_cdecl("vhs_ui_create") public func createRuntime(_ bridge: OpaquePointer, _ shaderPath: UnsafePointer<CChar>) -> UnsafeMutableRawPointer? {
    guard Thread.isMainThread, let runtime = try? PluginRuntime(bridge, shaderURL: URL(fileURLWithPath: String(cString: shaderPath))) else { return nil }
    return Unmanaged.passRetained(runtime).toOpaque()
}
@_cdecl("vhs_ui_attach") public func attachEditor(_ handle: UnsafeMutableRawPointer, _ parent: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    guard Thread.isMainThread else { return nil }
    let runtime = Unmanaged<PluginRuntime>.fromOpaque(handle).takeUnretainedValue()
    let parentView = Unmanaged<NSView>.fromOpaque(parent).takeUnretainedValue()
    let view = NSHostingView(rootView: PluginEditor(runtime: runtime))
    view.frame = parentView.bounds; view.autoresizingMask = [.width, .height]
    parentView.addSubview(view)
    return Unmanaged.passRetained(view).toOpaque()
}
@_cdecl("vhs_ui_detach") public func detachEditor(_ view: UnsafeMutableRawPointer) {
    guard Thread.isMainThread else { return }
    Unmanaged<NSView>.fromOpaque(view).takeRetainedValue().removeFromSuperview()
}
@_cdecl("vhs_ui_destroy") public nonisolated func destroyRuntime(_ handle: UnsafeMutableRawPointer) {
    // A host may release its final component reference on a worker thread.
    let address = UInt(bitPattern: handle)
    let teardown: @MainActor @Sendable () -> Void = {
        let runtime = Unmanaged<PluginRuntime>.fromOpaque(UnsafeMutableRawPointer(bitPattern: address)!).takeRetainedValue()
        runtime.stop()
    }
    if Thread.isMainThread { MainActor.assumeIsolated { teardown() } }
    else { DispatchQueue.main.async { teardown() } }
}

@_cdecl("vhs_document_validate") public nonisolated func validateHostDocument(_ data: UnsafePointer<UInt8>?, _ count: UInt32) -> Int32 {
    guard let data, count > 0, count <= VHS_STATE_CAPACITY else { return 0 }
    return (try? HostDocumentCodec.decode(Data(bytes:data,count:Int(count)))) == nil ? 0 : 1
}
