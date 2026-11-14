import AppKit
import SwiftUI
import VHSCore
import VHSGraphUI
import VHSDevices
import VHSSignal

enum MappingVerification {
    enum Failure: Error { case check(String) }
    static func run(_ model: AppModel) throws {
        func check(_ ok: Bool, _ message: String) throws {
            guard ok else { throw Failure.check(message) }; Verification.log("PASS \(message)")
        }
        let prior = model.document
        defer { model.inputs.fixture(.init(),audioRunning:false,midiRunning:false); model.replaceProject(prior) }
        model.replaceProject(.init())
        let target = GraphParameterTarget(node:ShaderGraph.sourceID,key:ParameterID.solidRed.rawValue)
        var m = VisualMapping(target:target); m.upper = 0.5
        model.send(.setMappings([m]))
        let saved = model.document, history = model.history
        var snapshot = InputSnapshot(); snapshot.mappingInputs.audio[.rms] = 1
        model.inputs.fixture(snapshot,audioRunning:true,midiRunning:false)
        model.tick()
        try check(model.frame.scene.number(.solidRed) == 0.74,"mapping updates common preview/output frame")
        try check(model.document == saved && model.history.past == history.past,"live mapping never dirties base values or adds history")
        model.undo(); try check(model.scene.mappings.isEmpty,"mapping definition undo")
        model.redo(); try check(model.scene.mappings == [m],"mapping definition redo")
        let state = model.mappingEditor
        state.learn(m); state.accept(channel:3,number:74,note:false)
        try check(state.candidate?.source == .cc && state.candidate?.number == 74 && state.candidate?.channel == nil,"learn reviews channel/CC with explicit Omni policy")
        state.cancel(); try check(state.candidate == nil && model.scene.mappings == [m],"cancel learn preserves saved assignment")
        m.channel = 2; state.learn(m); state.accept(channel:3,number:60,note:true)
        try check(state.waiting && state.candidate == nil,"learn respects explicit channel filter")
        state.accept(channel:2,number:60,note:true)
        let candidate = try state.candidate.map { $0 } ?? { throw Failure.check("note candidate") }()
        let confirmed = MappingLearn.confirm(candidate,in:model.scene.mappings,replaceConflicts:false)!
        model.send(.setMappings(confirmed)); state.cancel()
        try check(model.scene.mappings.first?.source == .gate && model.scene.mappings.first?.number == 60,"confirm note learn commits one persisted definition")
        try check(try ProjectCodec.decode(ProjectCodec.encode(model.document)) == model.document,"learned mapping project round trip")
        model.inputs.fixture(.init(),audioRunning:false,midiRunning:false); model.tick()
        try check(model.frame.scene.color == model.scene.color,"input release restores base frame")
    }
    static func snapshots(_ model: AppModel, control: NSWindow, directory: String) async throws {
        let window = NSWindow(contentRect:.init(x:0,y:0,width:Layout.mappingWidth,height:Layout.mappingHeight),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false; window.title = "VHS Mappings fixture"
        defer { window.contentView = nil; window.close(); NSApp.appearance = nil }
        let target = GraphParameterTarget(node:ShaderGraph.sourceID,key:ParameterID.solidRed.rawValue)
        var m = VisualMapping(target:target); m.source = .cc; m.number = 74
        for (mode,appearance) in SignalSnapshots.appearances {
            NSApp.appearance = NSAppearance(named:appearance)
            for name in ["empty","assigned","waiting","no-input","candidate","conflict","unavailable","disabled","host"] {
                let state = MappingEditorState(); state.selected = m.id
                var scene = SceneSnapshot().withMappings([m])
                if name == "empty" { scene = SceneSnapshot() }
                if name == "disabled" { var disabled = m; disabled.enabled = false; scene = scene.withMappings([disabled]) }
                if name == "unavailable" { scene = SceneReducer.reduce(scene,.selectSource(.gradient)) }
                if ["waiting","no-input","candidate","conflict"].contains(name) { state.learn(m) }
                if ["candidate","conflict"].contains(name) { state.accept(channel:3,number:74,note:false) }
                if name == "conflict" { var other = VisualMapping(target:.init(node:target.node,key:ParameterID.solidBlue.rawValue)); other.source = .cc; other.number = 74; scene = scene.withMappings([m,other]) }
                state.inputAvailable = name != "no-input"
                state.feedback = [target:0.8]
                window.contentView = NSHostingView(rootView:MappingEditor(scene:scene,state:state,host:name == "host",send:{ _ in }))
                control.orderOut(nil); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(nil)
                try await Task.sleep(for:.milliseconds(120))
                let path = "\(directory)/mappings-\(name)-\(mode)"
                GridProbes.shared.write(to:path+"-layout.json",window:window.contentLayoutRect.size)
                try Verification.capture(window,to:path+".png")
                if let scroll = scrollView(window.contentView!), let doc = scroll.documentView {
                    doc.scroll(NSPoint(x:0,y:doc.bounds.maxY)); scroll.reflectScrolledClipView(scroll.contentView)
                    try await Task.sleep(for:.milliseconds(60))
                    GridProbes.shared.write(to:path+"-bottom-layout.json",window:window.contentLayoutRect.size)
                    try Verification.capture(window,to:path+"-bottom.png")
                }
            }
            window.contentView = nil; window.orderOut(nil)
            for (name,size) in [("default",NSSize(width:Layout.defaultWidth,height:Layout.defaultHeight)),("minimum",NSSize(width:Layout.minWidth,height:Layout.minHeight)),("wide",NSSize(width:1440,height:900))] {
                control.setContentSize(size); control.makeKeyAndOrderFront(nil)
                try await Task.sleep(for:.milliseconds(100))
                GridProbes.shared.write(to:"\(directory)/mapping-toolbar-\(name)-\(mode)-layout.json",window:size)
            }
        }
    }
    private static func scrollView(_ view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { scrollView($0) }.first
    }
}
