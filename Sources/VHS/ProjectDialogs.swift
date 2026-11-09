import AppKit
import UniformTypeIdentifiers

extension UTType {
    static let vhsProject = UTType(exportedAs: "com.kike.vhs.project", conformingTo: .json)
}

enum UnsavedChoice { case save, discard, cancel }

protocol ProjectDialogs: AnyObject {
    func chooseOpenURL() async -> URL?
    func chooseSaveURL(name: String, currentURL: URL?) async -> URL?
    func confirmUnsaved(name: String) async -> UnsavedChoice
    func showError(title: String, message: String) async
}

final class NativeProjectDialogs: ProjectDialogs {
    private var window: NSWindow? { NSApp.windows.first { $0.identifier?.rawValue == "vhs-control" } }
    func chooseOpenURL() async -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Open Project"
        panel.allowedContentTypes = [.vhsProject]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = window?.representedURL?.deletingLastPathComponent()
        return await run(panel) == .OK ? panel.url : nil
    }
    func chooseSaveURL(name: String, currentURL: URL?) async -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save Project"
        panel.allowedContentTypes = [.vhsProject]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = name + ".vhsproject"
        panel.directoryURL = currentURL?.deletingLastPathComponent()
        return await run(panel) == .OK ? panel.url : nil
    }
    func confirmUnsaved(name: String) async -> UnsavedChoice {
        let alert = NSAlert()
        alert.messageText = "Save changes to “\(name)”?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
        switch await run(alert) {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .discard
        default: return .cancel
        }
    }
    func showError(title: String, message: String) async {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        _ = await run(alert)
    }
    private func run(_ panel: NSSavePanel) async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            if let window { panel.beginSheetModal(for: window) { continuation.resume(returning: $0) } }
            else { panel.begin { continuation.resume(returning: $0) } }
        }
    }
    private func run(_ alert: NSAlert) async -> NSApplication.ModalResponse {
        if let window {
            return await withCheckedContinuation { continuation in
                alert.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            }
        }
        return alert.runModal()
    }
}
