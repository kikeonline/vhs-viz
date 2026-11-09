import AppKit
import VHSCore

enum ProjectSnapshots {
    static func run(_ model: AppModel, control: NSWindow, directory: String) async throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("VHS-project-shots-\(UUID())")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let savedURL = temporary.appendingPathComponent("Sunset Session.vhsproject")
        let collision = temporary.appendingPathComponent("Existing Show.vhsproject")
        try ProjectStore().write(.init(name: "Existing Show"), to: collision)
        let broken = temporary.appendingPathComponent("Broken.vhsproject")
        try Data("not a project".utf8).write(to: broken)
        model.output.window?.performClose(nil)
        control.setContentSize(NSSize(width: Layout.defaultWidth, height: Layout.defaultHeight))
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            model.replaceProject(.init(name: "Sunset Session"))
            _ = await model.files.saveProject(to: savedURL)
            try await capture(control, name: "saved-\(mode)", directory: directory)
            model.files.beginRename()
            try await Task.sleep(for: .milliseconds(400))
            do {
                let sheet = try await sheet(in: control)
                try await capture(sheet, name: "rename-\(mode)", directory: directory, layout: true)
                try Verification.shortcut("a", modifiers: .command)
                try Verification.typeText("Existing Show")
                try Verification.pressReturn()
                try await Task.sleep(for: .milliseconds(400))
                try await capture(sheet, name: "rename-invalid-\(mode)", directory: directory, layout: true)
            }
            model.files.isRenaming = false
            try await Task.sleep(for: .milliseconds(300))
            model.send(.setParameter(.solidRed, 0.88))
            try await capture(control, name: "edited-\(mode)", directory: directory)
            let unsaved = Task { await NativeProjectDialogs().confirmUnsaved(name: model.projectName) }
            try await Task.sleep(for: .milliseconds(300))
            do {
                let sheet = try await sheet(in: control)
                try await capture(control, name: "unsaved-\(mode)", directory: directory)
                control.endSheet(sheet, returnCode: .alertThirdButtonReturn)
                sheet.orderOut(nil)
            }
            _ = await unsaved.value
            try await Task.sleep(for: .milliseconds(250))
            let invalidOpen = Task { await model.files.openProject(broken) }
            try await Task.sleep(for: .milliseconds(300))
            do {
                let sheet = try await sheet(in: control)
                try await capture(control, name: "open-error-\(mode)", directory: directory)
                control.endSheet(sheet, returnCode: .alertFirstButtonReturn)
                sheet.orderOut(nil)
            }
            await invalidOpen.value
            try await Task.sleep(for: .milliseconds(250))
            let save = Task { await NativeProjectDialogs().chooseSaveURL(name: model.projectName, currentURL: model.fileURL) }
            try await Task.sleep(for: .milliseconds(600))
            do {
                let sheet = try await sheet(in: control)
                try await capture(sheet, name: "save-\(mode)", directory: directory)
                control.endSheet(sheet, returnCode: .cancel)
                sheet.orderOut(nil)
            }
            _ = await save.value
            try await Task.sleep(for: .milliseconds(250))
            let open = Task { await NativeProjectDialogs().chooseOpenURL() }
            try await Task.sleep(for: .milliseconds(600))
            do {
                let sheet = try await sheet(in: control)
                try await capture(sheet, name: "open-\(mode)", directory: directory)
                control.endSheet(sheet, returnCode: .cancel)
                sheet.orderOut(nil)
            }
            _ = await open.value
        }
        model.replaceProject(.init())
    }
    private static func sheet(in window: NSWindow) async throws -> NSWindow {
        for _ in 0..<80 {
            if let sheet = window.attachedSheet { return sheet }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw ProjectVerification.Failure(message: "Expected a project dialog sheet")
    }
    private static func capture(_ window: NSWindow, name: String, directory: String, layout: Bool = false) async throws {
        NSApp.activate(); window.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(250))
        let path = "\(directory)/\(name)"
        if layout {
            GridProbes.shared.write(to: path + "-layout.json", window: window.contentView?.bounds.size ?? .zero)
        }
        try Verification.capture(window, to: path + ".png")
    }
}
