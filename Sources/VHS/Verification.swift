import AppKit
import VHSCore

/// Opt-in verification against ephemeral scene state; no user files are read or written.
enum Verification {
    private static var started = false
    static func runIfRequested(model: AppModel) async {
        guard !started else { return }
        started = true
        let env = ProcessInfo.processInfo.environment
        guard env["APP_SNAPSHOT"] != nil || CommandLine.arguments.contains("--selftest") else { return }
        do {
            try await Task.sleep(for: .seconds(1))
            if CommandLine.arguments.contains("--selftest") {
                try await selftest(model)
            }
            if let directory = env["APP_SNAPSHOT"] {
                try await snapshots(model, directory: directory)
            }
            NSApp.terminate(nil)
        } catch {
            FileHandle.standardError.write(Data("FAIL \(error)\n".utf8))
            exit(1)
        }
    }
    private struct Failure: Error, CustomStringConvertible { let description: String }
    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(description: message) }
        print("PASS \(message)")
    }
    private static func selftest(_ model: AppModel) async throws {
        try check(model.renderer != nil, "Metal renderer initialized")
        let editMenu = NSApp.mainMenu?.items.first { $0.title == "Edit" }?.submenu
        let undoItem = editMenu?.items.first { $0.title == "Undo Color Change" }
        let redoItem = editMenu?.items.first { $0.title == "Redo Color Change" }
        try check(undoItem?.isEnabled == false && redoItem?.isEnabled == false, "native Edit menu starts with undo and redo disabled")
        let initial = model.scene
        model.beginEdit()
        for value in [0.1, 0.3, 0.5, 0.9] { model.send(.setParameter(.solidRed, value)) }
        model.endEdit()
        let edited = model.scene
        try check(undoItem?.isEnabled == true && redoItem?.isEnabled == false, "native Edit menu enables undo after an edit")
        try check(model.history.past.count == 1, "slider gesture creates one history entry")
        try await Task.sleep(for: .milliseconds(200))
        try shortcut("z", modifiers: .command)
        try await Task.sleep(for: .milliseconds(200))
        try check(model.scene == initial && model.history.canRedo, "Command-Z restores initial scene and enables redo")
        try check(undoItem?.isEnabled == false && redoItem?.isEnabled == true, "native Edit menu enables redo after undo")
        try await Task.sleep(for: .milliseconds(200))
        try shortcut("z", modifiers: [.command, .shift])
        try await Task.sleep(for: .milliseconds(200))
        try check(model.scene == edited && model.history.canUndo, "Shift-Command-Z restores edited scene")
        try shortcut("o", modifiers: [.command, .shift])
        try await Task.sleep(for: .seconds(0.4))
        guard let output = model.output.window else { throw Failure(description: "output opens") }
        try check(output.contentView != nil && output.isVisible, "output opens with live view")
        output.setContentSize(NSSize(width: 640, height: 360))
        try await Task.sleep(for: .seconds(0.3))
        output.performClose(nil)
        try check(model.output.window == nil && model.scene == edited, "closing output releases view and preserves scene")
        model.output.show()
        try await Task.sleep(for: .seconds(0.3))
        try check(model.output.window !== output && model.scene == edited, "reopening output uses existing scene")
        try shortcut("1", modifiers: .command)
        try await Task.sleep(for: .milliseconds(200))
        try check(NSApp.windows.contains { $0.title == "Untitled Scene" && $0.isVisible }, "Command-1 shows control window from output")
        if let renderer = model.renderer {
            let pixels = try renderer.readPixels(model.frame, width: 8, height: 8)
            try check(pixels.count == 256 && pixels[2] > pixels[1], "GPU draws edited scene")
        }
        // Exercise the live display delegates and shared-clock timer, not just setup.
        try await Task.sleep(for: .seconds(2))
        try check(model.errorMessage == nil && model.frame.time > 0, "live rendering and shared clock run without errors")
        model.output.window?.performClose(nil)
        model.undo()
        print("SELFTEST done")
    }
    private static func shortcut(_ key: String, modifiers: NSEvent.ModifierFlags) throws {
        for item in NSApp.mainMenu?.items ?? [] { item.submenu?.update() }
        guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                    timestamp: 0, windowNumber: NSApp.keyWindow?.windowNumber ?? 0, context: nil,
                    characters: modifiers.contains(.shift) ? key.uppercased() : key,
                    charactersIgnoringModifiers: modifiers.contains(.shift) ? key.uppercased() : key,
                    isARepeat: false, keyCode: 0),
              NSApp.mainMenu?.performKeyEquivalent(with: event) == true else {
            throw Failure(description: "Menu shortcut did not dispatch: \(key)")
        }
    }
    private static func snapshots(_ model: AppModel, directory: String) async throws {
        var captureFailures: [String] = []
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        guard let control = NSApp.windows.first(where: { $0.title == "Untitled Scene" }) else {
            throw Failure(description: "control window missing")
        }
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            for (name, size) in [("control", NSSize(width: Layout.defaultWidth, height: Layout.defaultHeight)),
                                 ("control-minimum", NSSize(width: Layout.minWidth, height: Layout.minHeight))] {
                control.setContentSize(size)
                NSApp.activate(); control.makeKeyAndOrderFront(nil)
                control.makeFirstResponder(nil)
                try await Task.sleep(for: .seconds(0.7))
                let path = "\(directory)/\(name)-\(mode)"
                GridProbes.shared.write(to: path + "-layout.json", window: size)
                do { try capture(control, to: path + ".png") }
                catch { captureFailures.append("\(name)-\(mode): \(error)") }
            }
        }
        model.output.show()
        try await Task.sleep(for: .seconds(0.7))
        if let output = model.output.window {
            do { try capture(output, to: "\(directory)/output.png") }
            catch { captureFailures.append("output: \(error)") }
        }
        if !captureFailures.isEmpty {
            throw Failure(description: captureFailures.joined(separator: "\n"))
        }
        print("SNAPSHOT done \(directory)")
    }
    private static func capture(_ window: NSWindow, to path: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: path) else {
            throw Failure(description: "Unable to capture window. Allow Screen Recording for the launching terminal.")
        }
        print("SNAPSHOT \(path)")
    }
}
