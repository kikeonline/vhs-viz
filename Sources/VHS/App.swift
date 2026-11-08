import SwiftUI

@main struct VHSApp: App {
    @State private var model = AppModel()
    @ObservedObject private var menu = MenuState.shared
    var body: some Scene {
        // Read in App.body so command values change when history changes.
        let canUndo = menu.canUndo
        let canRedo = menu.canRedo
        return Window("Untitled Scene", id: "control") { ControlView(model: model) }
            .defaultSize(width: Layout.defaultWidth, height: Layout.defaultHeight)
            .windowResizability(.contentMinSize)
            .commands { VHSCommands(model: model, canUndo: canUndo, canRedo: canRedo) }
    }
}
