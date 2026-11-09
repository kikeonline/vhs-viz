import AppKit
import MetalKit
import VHSCore

/// Opt-in verification against ephemeral scene state; no user files are read or written.
enum Verification {
    private static var started = false
    static func log(_ message: String) { FileHandle.standardOutput.write(Data((message + "\n").utf8)) }
    static func runIfRequested(model: AppModel) async {
        guard !started else { return }
        started = true
        let env = ProcessInfo.processInfo.environment
        guard env["APP_SNAPSHOT"] != nil || CommandLine.arguments.contains("--selftest") else { return }
        let watchdog = DispatchWorkItem { @Sendable in
            FileHandle.standardError.write(Data("FAIL verification timed out\n".utf8))
            exit(1)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: watchdog)
        defer { watchdog.cancel() }
        do {
            try await Task.sleep(for: .seconds(1))
            if CommandLine.arguments.contains("--selftest") {
                try await selftest(model)
                try await ProjectVerification.run(model)
                log("SELFTEST done")
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
        log("PASS \(message)")
    }
    private static func selftest(_ model: AppModel) async throws {
        try check(model.renderer != nil, "Metal renderer initialized")
        try check(!model.history.canUndo && !model.history.canRedo, "history starts with undo and redo unavailable")
        let initial = model.scene
        model.beginEdit()
        for value in [0.1, 0.3, 0.5, 0.9] { model.send(.setParameter(.solidRed, value)) }
        model.endEdit()
        let edited = model.scene
        try check(MenuState.shared.canUndo && !MenuState.shared.canRedo, "history changes publish command availability")
        try check(model.history.past.count == 1, "slider gesture creates one history entry")
        try await Task.sleep(for: .milliseconds(200))
        try shortcut("z", modifiers: .command)
        try await Task.sleep(for: .milliseconds(200))
        try check(model.scene == initial && model.history.canRedo, "Command-Z restores initial scene and enables redo")
        try check(!MenuState.shared.canUndo && MenuState.shared.canRedo, "undo publishes redo availability")
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
        try check(NSApp.windows.contains { $0.identifier?.rawValue == "vhs-control" && $0.isVisible }, "Command-1 shows control window from output")
        if let renderer = model.renderer {
            let pixels = try renderer.readPixels(model.frame, width: 8, height: 8)
            try check(pixels.count == 256 && pixels[2] > pixels[1], "GPU draws edited scene")
        }
        // Exercise the live display delegates and shared-clock timer, not just setup.
        func coordinator(in view: NSView) -> MetalSurface.Coordinator? {
            if let metal = view as? MTKView { return metal.delegate as? MetalSurface.Coordinator }
            return view.subviews.lazy.compactMap { coordinator(in: $0) }.first
        }
        let control = NSApp.windows.first { $0.identifier?.rawValue == "vhs-control" }
        guard let preview = control?.contentView.flatMap({ coordinator(in: $0) }),
              let performance = model.output.window?.contentView.flatMap({ coordinator(in: $0) }) else {
            throw Failure(description: "live surface coordinators exist")
        }
        let previewFrames = preview.drawableFrameCount
        let outputFrames = performance.drawableFrameCount
        try await Task.sleep(for: .seconds(2))
        try check(preview.drawableFrameCount > previewFrames && performance.drawableFrameCount > outputFrames,
                  "preview and output acquire and render live drawables")
        try check(model.errorMessage == nil && model.frame.time > 0, "live rendering and shared clock run without errors")
        model.output.window?.performClose(nil)
        model.undo()
        model.discardChanges()
    }
    static func shortcut(_ key: String, modifiers: NSEvent.ModifierFlags) throws {
        // Regression: SwiftUI may rebuild menus when they are opened or validated.
        // Hand-inserted NSMenuItems disappeared here even though direct menu tests passed.
        for item in NSApp.mainMenu?.items ?? [] {
            if let submenu = item.submenu { submenu.delegate?.menuNeedsUpdate?(submenu) }
        }
        let keyCode: CGKeyCode = ["z": 6, "o": 31, "1": 18, "n": 45, "s": 1, "r": 15, "a": 0, "q": 12][key] ?? 0
        guard let keyboard = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            throw Failure(description: "Unable to create shortcut event: \(key)")
        }
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        keyboard.flags = flags
        guard let event = NSEvent(cgEvent: keyboard) else {
            throw Failure(description: "Unable to convert shortcut event: \(key)")
        }
        // Exercise NSApplication routing, including window responders and menu validation.
        // Calling NSMenu.performKeyEquivalent directly bypassed the failing user path.
        NSApp.sendEvent(event)
    }
    static func typeText(_ text: String) throws {
        for character in text {
            guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                        windowNumber: NSApp.keyWindow?.windowNumber ?? 0, context: nil,
                        characters: String(character), charactersIgnoringModifiers: String(character), isARepeat: false, keyCode: 0) else {
                throw Failure(description: "Unable to type text")
            }
            NSApp.sendEvent(event)
        }
    }
    static func pressReturn() throws {
        guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                    windowNumber: NSApp.keyWindow?.windowNumber ?? 0, context: nil,
                    characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36) else {
            throw Failure(description: "Unable to press Return")
        }
        NSApp.sendEvent(event)
    }
    private static func snapshots(_ model: AppModel, directory: String) async throws {
        var captureFailures: [String] = []
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        guard let control = NSApp.windows.first(where: { $0.identifier?.rawValue == "vhs-control" }) else {
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
        try await ProjectSnapshots.run(model, control: control, directory: directory)
        log("SNAPSHOT done \(directory)")
    }
    static func capture(_ window: NSWindow, to path: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: path) else {
            throw Failure(description: "Unable to capture window. Allow Screen Recording for the launching terminal.")
        }
        log("SNAPSHOT \(path)")
    }
}
