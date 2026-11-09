import SwiftUI

/// Commands stay in SwiftUI's menu tree so menu refreshes preserve them.
struct VHSCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    let model: AppModel
    let canUndo: Bool
    let canRedo: Bool
    let fileCommandsEnabled: Bool
    let canSave: Bool
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Project") { openWindow(id: "control"); Task { await model.files.newProject() } }
                .keyboardShortcut("n").disabled(!fileCommandsEnabled)
            Button("Open Project…") { openWindow(id: "control"); Task { await model.files.openProject() } }
                .keyboardShortcut("o").disabled(!fileCommandsEnabled)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save Project") { Task { _ = await model.files.saveProject() } }
                .keyboardShortcut("s").disabled(!canSave)
            Button("Save Project As…") { Task { _ = await model.files.saveProject(asNewFile: true) } }
                .keyboardShortcut("s", modifiers: [.command, .shift]).disabled(!fileCommandsEnabled)
            Button("Rename Project…") { openWindow(id: "control"); model.files.beginRename() }
                .keyboardShortcut("r", modifiers: [.command, .shift]).disabled(!fileCommandsEnabled)
        }
        CommandGroup(replacing: .undoRedo) {
            Button("Undo Color Change") { model.undo() }
                .keyboardShortcut("z").disabled(!canUndo)
            Button("Redo Color Change") { model.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift]).disabled(!canRedo)
        }
        CommandGroup(after: .windowArrangement) {
            Button("Show Control Window") { openWindow(id: "control") }
                .keyboardShortcut("1")
            Button("Show Output") { model.output.show() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
        }
    }
}
