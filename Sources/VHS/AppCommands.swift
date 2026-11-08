import AppKit

/// Native validation avoids stale SwiftUI Commands enablement for shared history.
final class AppCommands: NSObject, NSMenuItemValidation {
    private unowned let model: AppModel
    private var showControl: (() -> Void)?
    private weak var undoItem: NSMenuItem?
    private weak var redoItem: NSMenuItem?
    init(model: AppModel) { self.model = model }

    func install(showControl: @escaping () -> Void) {
        self.showControl = showControl
        if let windows = NSApp.mainMenu?.items.first(where: { $0.title == "Window" })?.submenu,
           !windows.items.contains(where: { $0.action == #selector(showOutput) }) {
            let control = NSMenuItem(title: "Show Control Window", action: #selector(showControlWindow), keyEquivalent: "1")
            control.target = self; control.keyEquivalentModifierMask = .command
            let output = NSMenuItem(title: "Show Output", action: #selector(showOutput), keyEquivalent: "O")
            output.target = self; output.keyEquivalentModifierMask = [.command, .shift]
            windows.addItem(.separator()); windows.addItem(control); windows.addItem(output)
        }
        guard let menu = NSApp.mainMenu?.items.first(where: { $0.title == "Edit" })?.submenu else { return }
        if let undoItem, menu.items.contains(undoItem) { refresh(); return }
        let undo = NSMenuItem(title: "Undo Color Change", action: #selector(undoColor), keyEquivalent: "z")
        undo.keyEquivalentModifierMask = .command
        undo.target = self
        let redo = NSMenuItem(title: "Redo Color Change", action: #selector(redoColor), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        redo.target = self
        menu.insertItem(.separator(), at: 0)
        menu.insertItem(redo, at: 0)
        menu.insertItem(undo, at: 0)
        undoItem = undo; redoItem = redo
        refresh()
    }
    func refresh() {
        undoItem?.isEnabled = model.history.canUndo
        redoItem?.isEnabled = model.history.canRedo
    }
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(undoColor): model.history.canUndo
        case #selector(redoColor): model.history.canRedo
        default: true
        }
    }
    @objc private func showOutput() { model.output.show() }
    @objc private func showControlWindow() { showControl?() }
    @objc private func undoColor() { model.undo() }
    @objc private func redoColor() { model.redo() }
}
