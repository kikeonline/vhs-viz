import SwiftUI

/// Commands stay in SwiftUI's menu tree so menu refreshes preserve them.
struct VHSCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    let model: AppModel
    let canUndo: Bool
    let canRedo: Bool
    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
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
