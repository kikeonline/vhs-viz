import AppKit
import SwiftUI
import VHSSignal
import VHSCore
import VHSRealtime
import VHSGraphUI

private enum ProbeFailure: Error { case check(String) }
/// A native embedding harness, separate from Studio One acceptance. Uses the real
/// runtime, timer, surfaces, output controller and generated host editor.
public func runPluginProbe(folder: String) async throws {
    func check(_ condition: @autoclosure () -> Bool, _ label: String) throws {
        guard condition() else { throw ProbeFailure.check(label) }
        print("PASS \(label)")
    }
    let directory = URL(fileURLWithPath: folder)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    guard let a = vhs_bridge_create(), let b = vhs_bridge_create() else { throw ProbeFailure.check("bridge allocation") }
    defer { vhs_bridge_release(a); vhs_bridge_release(b) }
    let first = try PluginRuntime(a), second = try PluginRuntime(b)
    defer { first.stop(); second.stop() }
    let window = NSWindow(contentRect: .init(x: 0, y: 0, width: Layout.defaultWidth, height: Layout.defaultHeight),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.title = "VHS Native Editor Probe"
    defer { window.contentView = nil; window.close() }
    window.contentView = NSHostingView(rootView: PluginEditor(runtime: first))
    window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate()
    vhs_bridge_set(a, 0, 0.7); first.tick(); second.tick()
    try check(first.red == 0.7 && second.red == 0.24, "base values stay independent")
    first.learning = true
    var event = VHSInput(); event.kind = 3; event.channel = 2; event.number = 74; event.value = 0.5; event.offset = 17
    vhs_bridge_push(a, event); first.tick()
    try check(first.candidate?.number == 74 && first.candidate?.channel == 2 && first.candidate?.offset == 17 && !first.learning, "learn detects channel/controller/offset")
    first.learnedChannel = 2; first.learnedController = 74; first.candidate = nil
    event.value = 0.25; vhs_bridge_push(a, event)
    var block = VHSInput(); block.kind = 0; block.value = 0.1; block.tempo = 139; block.flags = 7
    vhs_bridge_push(a, block); first.tick()
    try check(first.learnedValue == 0.25 && first.tempo == 139 && first.playing, "learned CC and host context reach display timer")
    event.kind = 1; event.channel = 0; event.number = 60; event.value = 0.75
    vhs_bridge_push(a, event); first.tick()
    try check(first.velocity == 0.75 && second.velocity == 0, "held notes stay independent")
    for _ in 0..<300 { vhs_bridge_push(a, event) }
    first.tick()
    try check(first.velocity == 0 && first.dropped > 0, "overflow clears queued held notes")
    first.showOutput(); second.showOutput()
    try check(first.output !== second.output && first.output?.isVisible == true && second.output?.isVisible == true, "two independent output windows")
    first.output?.close()
    try check(first.output == nil && second.output?.isVisible == true, "closing one output preserves the other")
    first.showOutput()
    window.contentView = nil
    try check(first.output?.isVisible == true, "detaching editor preserves output")
    window.contentView = NSHostingView(rootView: PluginEditor(runtime: second))
    first.learning = false; first.candidate = nil; first.learnedController = nil; first.learnedChannel = nil
    vhs_bridge_set(a, 0, 0.24); first.tick()
    first.output?.close(); second.output?.close()
    let aColor = GraphNode(kind:.color), aImage = GraphNode(kind:.imageFromColor), final = GraphNode(kind:.output)
    let graph = ShaderGraph(nodes:[aColor,aImage,final],edges:[.init(from:.init(aColor.id),to:.init(aImage.id,"color")),.init(from:.init(aImage.id),to:.init(final.id,"image"))])
    first.sendGraph(.setGraph(graph)); first.showsGraph = true
    first.setGraphLayout(.init(positions:[aImage.id.uuidString:.init(x:280,y:48)],zoom:0.75))
    first.tick()
    var bytes = [UInt8](repeating:0,count:Int(VHS_STATE_CAPACITY)), origin: UInt32 = 0, revision: UInt32 = 0
    let count = vhs_bridge_copy_document(a,&bytes,UInt32(bytes.count),&origin,&revision)
    try check(count > 0 && bytes.withUnsafeBufferPointer { validateHostDocument($0.baseAddress,UInt32(count)) } == 1,"graph host state validates without an editor or external file")
    let stored = bytes.withUnsafeBufferPointer { vhs_bridge_store_document(b,$0.baseAddress,UInt32(count),1) }
    second.tick()
    try check(stored == count && second.session.document == first.session.document && second.output == nil,"graph document/layout restore independently without auto-opening output")
    first.sendGraph(.setNodeValue(aColor.id,"value",.color(.init(red:0.8,green:0.1,blue:0.2))))
    try check(second.session.history.scene.graph == graph && first.session.history.scene.graph != graph,"graph edits do not leak between instances")
    for _ in 0..<150 {
        try await Task.sleep(for:.milliseconds(20)); second.tick()
        if second.render.frame.scene.graph == graph { break }
    }
    try check(second.render.frame.scene.graph == graph,"native plug-in renders a compiled branching/value graph")
    window.contentView = NSHostingView(rootView:PluginEditor(runtime:second))
    second.showsGraph = true; second.graphEditor.selection = aColor.id
    for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua), ("light-high-contrast", .accessibilityHighContrastAqua), ("dark-high-contrast", .accessibilityHighContrastDarkAqua)] {
        window.appearance = NSAppearance(named:appearance)
        for mode in ["editor","graph"] {
            second.showsGraph = mode == "graph"
            window.makeKeyAndOrderFront(nil); window.makeMain(); NSApp.activate()
            try await Task.sleep(for:.milliseconds(250))
            if ProcessInfo.processInfo.environment["APP_LAYOUT_ONLY"] != "1" {
                let activate = Process(); activate.executableURL = URL(fileURLWithPath:"/usr/bin/osascript")
                activate.arguments = ["-e","tell application \"System Events\" to set frontmost of (first process whose unix id is \(ProcessInfo.processInfo.processIdentifier)) to true"]
                try activate.run(); activate.waitUntilExit()
                try await Task.sleep(for:.milliseconds(250))
                try check(window.isKeyWindow,"\(name) \(mode) capture window is key")
                let path = directory.appendingPathComponent("plugin-\(mode)-\(name).png").path
                let capture = Process(); capture.executableURL = URL(fileURLWithPath:"/usr/sbin/screencapture")
                capture.arguments = ["-x","-o","-l",String(window.windowNumber),path]
                try capture.run(); capture.waitUntilExit()
                try check(capture.terminationStatus == 0,"\(name) \(mode) native window capture")
            } else { print("SKIP image capture (layout-only): plugin-\(mode)-\(name)") }
            let path = directory.appendingPathComponent("plugin-\(mode)-\(name)-layout.json").path
            if mode == "graph" { GraphEditorDiagnostics.writeLayout(to:path,width:window.contentLayoutRect.width,height:window.contentLayoutRect.height) }
            else { GridProbes.shared.write(to:path,window:window.contentLayoutRect.size) }
        }
    }
    first.showOutput(); first.stop()
    try check(first.output == nil && first.timer == nil, "instance teardown closes output and stops timer")
}

/// Pure fixture generation for the actual processor state tests, without AppKit windows.
public func writePluginGraphFixture(to path: String) throws {
    let a = GraphNode(kind:.source(.gradient)), b = GraphNode(kind:.source(.noise)), amount = GraphNode(kind:.scalar)
    let mix = GraphNode(kind:.imageMix), output = GraphNode(kind:.output)
    let graph = ShaderGraph(nodes:[a,b,amount,mix,output],edges:[
        .init(from:.init(a.id),to:.init(mix.id,"a")),.init(from:.init(b.id),to:.init(mix.id,"b")),
        .init(from:.init(amount.id),to:.init(mix.id,"amount")),.init(from:.init(mix.id),to:.init(output.id,"image"))])
    let document = ProjectDocument(name:"Graph Host Fixture",scene:SceneSnapshot(source:.noise,seed:678).withGraph(graph),
                                 graphLayout:.init(positions:[mix.id.uuidString:.init(x:480,y:240)],pan:.init(x:24,y:48),zoom:0.75))
    try ProjectCodec.encode(document).write(to:URL(fileURLWithPath:path),options:.atomic)
}
