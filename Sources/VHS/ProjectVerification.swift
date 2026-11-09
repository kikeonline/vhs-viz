import AppKit
import VHSCore

/// Scripted answers exercise the same transition code as real native dialogs.
final class ScriptedProjectDialogs: ProjectDialogs {
    var openURL: URL?
    var saveURL: URL?
    var choice: UnsavedChoice = .cancel
    var errors: [String] = []
    var confirmations = 0
    func chooseOpenURL() async -> URL? { openURL }
    func chooseSaveURL(name: String, currentURL: URL?) async -> URL? { saveURL }
    func confirmUnsaved(name: String) async -> UnsavedChoice { confirmations += 1; return choice }
    func showError(title: String, message: String) async { errors.append(title + ": " + message) }
}

enum ProjectVerification {
    struct Failure: Error { let message: String }
    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(message: message) }
        Verification.log("PASS \(message)")
    }
    private static func command(_ key: String, modifiers: NSEvent.ModifierFlags) async throws {
        // Give SwiftUI a turn to publish menu availability after the previous operation.
        try await Task.sleep(for: .milliseconds(150))
        try Verification.shortcut(key, modifiers: modifiers)
        try await Task.sleep(for: .milliseconds(150))
    }
    private static func wait(until predicate: () -> Bool) async throws {
        for _ in 0..<100 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw Failure(message: "Timed out waiting for project command")
    }
    static func run(_ model: AppModel) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VHS-project-selftest-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let originalDialogs = model.files.dialogs
        let dialogs = ScriptedProjectDialogs()
        model.files.dialogs = dialogs
        defer { model.files.dialogs = originalDialogs }
        try await command("n", modifiers: .command)
        try await Task.sleep(for: .milliseconds(200))
        try check(model.fileURL == nil && !model.isDirty && !model.history.canUndo, "New creates a pristine Untitled project")
        model.send(.setParameter(.solidRed, 0.77))
        let edited = model.document
        await model.files.newProject()
        try check(model.document == edited && model.isDirty, "Cancel prevents New from losing edits")
        dialogs.choice = .save; dialogs.saveURL = nil
        await model.files.newProject()
        try check(model.document == edited && model.isDirty, "cancelled Save panel prevents replacement")
        dialogs.saveURL = directory.appendingPathComponent("missing/Bad.vhsproject")
        await model.files.newProject()
        try check(model.document == edited && model.isDirty && !dialogs.errors.isEmpty, "failed Save prevents replacement and retains dirty state")
        dialogs.choice = .discard
        await model.files.newProject()
        try check(model.document.id != edited.id && !model.isDirty && !model.history.canUndo, "Don't Save permits New and resets history")
        let initialID = model.document.id
        try await command("r", modifiers: [.command, .shift])
        try await Task.sleep(for: .milliseconds(300))
        try check(model.files.isRenaming, "Shift-Command-R opens Rename Project")
        model.files.isRenaming = false
        try await Task.sleep(for: .milliseconds(300))
        try check(await model.files.renameProject(to: "First Show"), "rename Untitled project")
        try check(model.projectName == "First Show" && model.isDirty && model.fileURL == nil, "unsaved name becomes save suggestion")
        model.send(.setParameter(.solidBlue, 0.91))
        let first = directory.appendingPathComponent("First Show.vhsproject")
        dialogs.saveURL = first
        try await command("s", modifiers: .command)
        try await wait { model.fileURL == first }
        try check(model.fileURL == first, "Command-S saves first .vhsproject")
        try check(!model.isDirty && model.fileURL == first && model.document.id == initialID, "Save establishes URL and clean baseline")
        let savedScene = model.scene
        model.send(.setParameter(.solidGreen, 0.63))
        try check(model.isDirty, "scene edit marks project dirty")
        model.undo(); try check(!model.isDirty, "undo to saved state clears dirty state")
        model.redo()
        try check(await model.files.renameProject(to: "Renamed Show"), "rename saved file")
        let renamed = directory.appendingPathComponent("Renamed Show.vhsproject")
        try check(model.fileURL == renamed && model.isDirty && !FileManager.default.fileExists(atPath: first.path), "saved rename changes filename and preserves scene edits")
        let collision = directory.appendingPathComponent("Collision.vhsproject")
        try ProjectStore().write(.init(name: "Collision"), to: collision)
        try check(!(await model.files.renameProject(to: "Collision")), "rename refuses existing project")
        try check(model.fileURL == renamed && model.projectName == "Renamed Show", "failed rename preserves document identity and path")
        let copy = directory.appendingPathComponent("Copy.vhsproject")
        dialogs.saveURL = copy
        try await command("s", modifiers: [.command, .shift])
        try await wait { model.fileURL == copy }
        try check(model.fileURL == copy, "Shift-Command-S writes another project file")
        try check(model.fileURL == copy && !model.isDirty && FileManager.default.fileExists(atPath: renamed.path), "Save As preserves original and switches active URL")
        let beforeInvalid = model.document
        let beforeHistory = model.history.past.count
        let bad = directory.appendingPathComponent("Broken.vhsproject")
        try Data("{broken".utf8).write(to: bad)
        await model.files.openProject(bad)
        try check(model.document == beforeInvalid && model.history.past.count == beforeHistory && model.fileURL == copy, "corrupt Open preserves current document and history")
        try Data(#"{"schemaVersion":999}"#.utf8).write(to: bad)
        await model.files.openProject(bad)
        try check(model.document == beforeInvalid && dialogs.errors.last?.contains("newer version") == true, "future-version Open is rejected without replacing current project")
        model.send(.setParameter(.solidRed, 0.11))
        let dirty = model.document
        dialogs.choice = .cancel
        await model.files.openProject(renamed)
        try check(model.document == dirty, "Cancel protects dirty project during Open")
        dialogs.choice = .discard
        dialogs.openURL = renamed
        try await command("o", modifiers: .command)
        try await wait { model.fileURL == renamed && !model.isDirty }
        try check(model.scene == savedScene && model.projectName == "Renamed Show" && !model.isDirty && !model.history.canUndo, "Open restores saved scene, filename title, and fresh history")
        model.replaceProject(.init(name: "Unsaved Replacement"))
        model.send(.setParameter(.solidRed, 0.19))
        let replacementID = model.document.id
        dialogs.choice = .save; dialogs.saveURL = renamed
        await model.files.openProject(renamed)
        try check(model.scene.color.red == 0.19 && model.document.id == replacementID && !model.isDirty,
                  "Open reads the committed file if Save replaces the selected candidate")
        model.output.show()
        model.send(.setParameter(.solidRed, 0.42))
        model.output.window?.performClose(nil)
        try check(model.isDirty, "closing output does not discard project edits")
        dialogs.choice = .cancel
        try check(!(await model.files.prepareToLeave()), "Cancel prevents close or quit")
        dialogs.choice = .save; dialogs.saveURL = renamed
        try check(await model.files.prepareToLeave(), "Save permits close or quit only after successful save")
        try check(!model.isDirty, "Save before departure marks the captured state clean")
        // Editor close must consult the real installed delegate, not just a helper.
        guard let control = NSApp.windows.first(where: { $0.identifier?.rawValue == "vhs-control" }) else {
            throw Failure(message: "Control window missing")
        }
        model.send(.setParameter(.solidRed, 0.88))
        dialogs.choice = .cancel
        control.performClose(nil)
        try await Task.sleep(for: .milliseconds(200))
        try check(control.isVisible && model.isDirty, "native editor close honors Cancel")
        dialogs.choice = .discard
        control.performClose(nil)
        try await Task.sleep(for: .milliseconds(200))
        try check(!control.isVisible && !model.isDirty, "Don't Save closes editor and discards scene edits")
        try await command("1", modifiers: .command)
        try await wait { NSApp.windows.contains { $0.identifier?.rawValue == "vhs-control" && $0.isVisible } }
        try check(model.fileURL == renamed, "Command-1 reopens the current project after editor close")
        await model.files.newProject()
        try check(!model.isDirty && model.fileURL == nil, "self-test ends with an ephemeral clean project")
        Verification.log("PASS project lifecycle self-test")
    }
}
