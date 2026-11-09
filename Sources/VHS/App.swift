import SwiftUI

@main struct VHSApp: App {
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(ProjectAppDelegate.self) private var appDelegate
    @State private var model = AppModel()
    @ObservedObject private var menu = MenuState.shared
    var body: some Scene {
        let _ = appDelegate.connect(model, showControl: { openWindow(id: "control") })
        // Read in App.body so command values change when history changes.
        let canUndo = menu.canUndo
        let canRedo = menu.canRedo
        let fileCommandsEnabled = menu.fileCommandsEnabled
        let canSave = menu.canSave
        return Window("VHS", id: "control") {
            ControlView(model: model)
        }
            .defaultSize(width: Layout.defaultWidth, height: Layout.defaultHeight)
            .windowResizability(.contentMinSize)
            .commands { VHSCommands(model: model, canUndo: canUndo, canRedo: canRedo,
                                    fileCommandsEnabled: fileCommandsEnabled, canSave: canSave) }
    }
}
