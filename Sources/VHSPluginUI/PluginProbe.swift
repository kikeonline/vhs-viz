import AppKit
import SwiftUI
import VHSCore
import VHSRealtime

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
    for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
        window.appearance = NSAppearance(named: appearance)
        window.makeKeyAndOrderFront(nil); window.makeMain(); NSApp.activate()
        let activate = Process(); activate.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        activate.arguments = ["-e", "tell application \"System Events\" to set frontmost of (first process whose unix id is \(ProcessInfo.processInfo.processIdentifier)) to true"]
        try activate.run(); activate.waitUntilExit()
        try await Task.sleep(for: .milliseconds(400))
        try check(window.isKeyWindow, "\(name) capture window is key")
        let path = directory.appendingPathComponent("plugin-editor-\(name).png").path
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
        try process.run(); process.waitUntilExit()
        try check(process.terminationStatus == 0, "\(name) native window capture")
        GridProbes.shared.write(to: directory.appendingPathComponent("plugin-editor-\(name)-layout.json").path, window: window.contentLayoutRect.size)
    }
    first.showOutput(); first.stop()
    try check(first.output == nil && first.timer == nil, "instance teardown closes output and stops timer")
}
