import VHSSignal
import AppKit
import VHSCore
import VHSGraphUI

enum GraphSnapshots {
    static func run(_ model: AppModel, control: NSWindow, directory: String) async throws {
        model.output.window?.performClose(nil)
        func scroll(_ view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView { return scroll }
            return view.subviews.lazy.compactMap { scroll($0) }.first
        }
        for (mode, appearance) in SignalSnapshots.appearances {
            NSApp.appearance = NSAppearance(named: appearance)
            for name in ["migrated","branch","error"] {
                let scene: SceneSnapshot
                if name == "migrated" { scene = .init(source:.shape,effects:[.init(kind:.transform)]) }
                else {
                    var graph = try GraphVerification.example()
                    if name == "error" { graph = try graph.connecting(nil,to:.init(graph.nodes.last!.id,"image")) }
                    scene = SceneSnapshot().withGraph(graph)
                }
                model.replaceProject(.init(scene:scene)); model.showsGraph = true
                model.graphEditor.selection = name == "migrated" ? scene.graph.nodes[0].id : scene.graph.nodes[2].id
                for (suffix,size) in [("",NSSize(width:Layout.graphMinWidth+Space.section,height:Layout.defaultHeight)),
                                      ("-minimum",NSSize(width:Layout.graphMinWidth,height:Layout.graphMinHeight))] {
                    control.setContentSize(size); NSApp.activate(); control.makeKeyAndOrderFront(nil); control.makeFirstResponder(nil)
                    try await Task.sleep(for:.milliseconds(400))
                    let path = "\(directory)/nodes-\(name)\(suffix)-\(mode)"
                    GridProbes.shared.write(to:path+"-layout.json",window:size)
                    GraphEditorDiagnostics.writeLayout(to:path+"-editor-layout.json",width:size.width,height:size.height)
                    try Verification.capture(control,to:path+".png")
                }
                if name == "branch" {
                    model.output.show(); try await Task.sleep(for:.milliseconds(200))
                    if let output = model.output.window { try Verification.capture(output,to:"\(directory)/nodes-output-\(mode).png") }
                    model.output.window?.performClose(nil)
                }
                if name == "migrated", let scroll = control.contentView.flatMap({ scroll($0) }), let document = scroll.documentView {
                    document.scroll(.init(x:0,y:document.bounds.maxY)); scroll.reflectScrolledClipView(scroll.contentView)
                    try await Task.sleep(for:.milliseconds(200))
                    let path = "\(directory)/nodes-inspector-bottom-\(mode)"
                    GraphEditorDiagnostics.writeLayout(to:path+"-layout.json",width:Layout.graphMinWidth,height:Layout.graphMinHeight)
                    try Verification.capture(control,to:path+".png")
                }
            }
            model.graphEditor.showingLibrary = true
            try await Task.sleep(for:.milliseconds(300))
            GraphEditorDiagnostics.writeLayout(to:"\(directory)/nodes-library-\(mode)-layout.json",width:Layout.graphMinWidth,height:Layout.graphMinHeight)
            model.graphEditor.showingLibrary = false
        }
        model.replaceProject(.init()); model.showsGraph = false
    }
}
