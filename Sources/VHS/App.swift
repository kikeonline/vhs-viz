import SwiftUI

@main struct VHSApp: App {
    @State private var model = AppModel()
    var body: some Scene {
        Window("Untitled Scene", id: "control") { ControlView(model: model) }
            .defaultSize(width: Layout.defaultWidth, height: Layout.defaultHeight)
            .windowResizability(.contentMinSize)
            .commands {
                CommandGroup(replacing: .newItem) {}
                // Native validated commands are installed once the menu exists.
                CommandGroup(replacing: .undoRedo) {}
            }
    }
}
