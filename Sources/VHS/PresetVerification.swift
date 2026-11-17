import Foundation
import AppKit
import SwiftUI
import VHSCore
import VHSGraphUI
import VHSSignal

enum PresetVerification {
    enum Failure: Error { case check(String) }
    static func run(_ model: AppModel) async throws {
        func check(_ ok: Bool, _ message: String) throws {
            guard ok else { throw Failure.check(message) }; Verification.log("PASS \(message)")
        }
        let original = model.document
        defer { model.replaceProject(original) }
        model.replaceProject(.init(name:"Preset Test"))
        let before = model.document
        let selected = FactoryPresets.all[2]
        let state = PresetBrowserState()
        state.selected = selected.name; state.search = "Blend"
        try check(state.names == [selected.name] && model.document == before,"preset search/selection leaves live scene unchanged")
        try await model.loadPreset(selected)
        try check(model.scene == selected.scene && model.history.past.count == 1 && model.isDirty,"standalone preset load is one dirty undoable scene replacement")
        try check(model.document.id == before.id && model.projectName == before.name && model.fileURL == nil,"preset load preserves project identity and file ownership")
        model.undo(); try check(model.document == before,"preset undo restores complete prior scene")
        model.redo(); try check(model.scene == selected.scene,"preset redo restores complete loaded scene")
        let valid = model.document, count = model.history.past.count
        do {
            try await model.loadPreset(.init(name:"Broken",scene:selected.scene.withGraph(.init(nodes:[],edges:[]))))
            throw Failure.check("invalid preset accepted")
        } catch is GraphDiagnostic {}
        try check(model.document == valid && model.history.past.count == count,"invalid preset preserves standalone state and history")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VHS-preset-selftest-\(UUID())")
        defer { try? FileManager.default.removeItem(at:directory) }
        let library = PresetLibrary(directory:directory), browser = PresetBrowserState(library:PresetLibrary(directory:directory))
        await browser.perform { try await library.save(selected.named("User Blend")) }
        try check(browser.users == ["User Blend"],"shared browser refresh finds saved user presets")
        browser.scope = .user; browser.selected = "User Blend"
        let user = try await browser.document()
        try check(user.scene == selected.scene,"shared user selection reads embedded scene")
        await browser.perform { try await library.save(user) }
        try check(browser.message != nil && browser.users == ["User Blend"],"shared browser collision error preserves library")
        let saved = try ProjectCodec.encode(model.document)
        try await library.delete("User Blend")
        try check(try ProjectCodec.decode(saved).scene == selected.scene,"saved project recalls preset without library file")
    }
    static func snapshots(_ model: AppModel, control: NSWindow, directory: String) async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("VHS-preset-layout-\(UUID())")
        defer { try? FileManager.default.removeItem(at:folder); NSApp.appearance = nil }
        let library = PresetLibrary(directory:folder)
        try await library.save(FactoryPresets.all[2].named(Array(repeating:"Long preset",count:10).joined(separator:" ")))
        let window = NSWindow(contentRect:.init(x:0,y:0,width:Layout.presetWidth,height:Layout.presetHeight),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false; window.title = "VHS Presets"
        defer { window.contentView = nil; window.close() }
        for (mode,appearance) in SignalSnapshots.appearances {
            NSApp.appearance = NSAppearance(named:appearance)
            for name in ["factory","user","empty","error"] {
                let state = PresetBrowserState(library:library)
                try await state.refresh()
                if name == "user" { state.scope = .user }
                if name == "empty" { state.search = "no results" }
                if name == "error" { state.message = "This preset needs a compatible version of VHS. The current scene is preserved." }
                window.contentView = NSHostingView(rootView:PresetBrowser(state:state,scene:model.scene,load:{ _ in }))
                control.orderOut(nil); window.makeKeyAndOrderFront(nil)
                try await Task.sleep(for:.milliseconds(180))
                // The view's task refresh completes before setting the fixture error.
                if name == "error" { state.message = "This preset needs a compatible version of VHS. The current scene is preserved." }
                try await Task.sleep(for:.milliseconds(60))
                let path = "\(directory)/presets-\(name)-\(mode)"
                GridProbes.shared.write(to:path+"-layout.json",window:window.contentLayoutRect.size)
                if ProcessInfo.processInfo.environment["APP_LAYOUT_ONLY"] != "1" {
                    let activate = Process(); activate.executableURL = URL(fileURLWithPath:"/usr/bin/osascript")
                    activate.arguments = ["-e","tell application \"System Events\" to set frontmost of (first process whose unix id is \(ProcessInfo.processInfo.processIdentifier)) to true"]
                    try activate.run(); activate.waitUntilExit()
                    NSApp.activate(); window.makeKeyAndOrderFront(nil)
                    try await Task.sleep(for:.milliseconds(200))
                }
                try Verification.capture(window,to:path+".png")
            }
        }
    }
}
