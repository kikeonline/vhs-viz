import AppKit
import SwiftUI

/// Updates native document chrome while preserving SwiftUI's existing window delegate.
struct ProjectWindow: NSViewRepresentable {
    let model: AppModel
    let title: String
    let fileURL: URL?
    let isDirty: Bool
    func makeNSView(context: Context) -> Attachment {
        let view = Attachment()
        view.model = model
        return view
    }
    func updateNSView(_ view: Attachment, context: Context) {
        view.window?.title = title
        view.window?.representedURL = fileURL
        view.window?.isDocumentEdited = isDirty
    }
    final class Attachment: NSView {
        weak var model: AppModel?
        private var closeDelegate: ProjectCloseDelegate?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, let model else { return }
            window.identifier = NSUserInterfaceItemIdentifier("vhs-control")
            window.isDocumentEdited = model.isDirty
            window.representedURL = model.fileURL
            let proxy = ProjectCloseDelegate(model: model, previous: window.delegate)
            closeDelegate = proxy
            window.delegate = proxy
        }
    }
}

private final class ProjectCloseDelegate: NSObject, NSWindowDelegate {
    private unowned let model: AppModel
    private weak var previous: (any NSWindowDelegate)?
    private var allowCloseOnce = false
    init(model: AppModel, previous: (any NSWindowDelegate)?) { self.model = model; self.previous = previous }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if allowCloseOnce { allowCloseOnce = false; return previous?.windowShouldClose?(sender) ?? true }
        guard model.isDirty || model.files.isBusy else { return previous?.windowShouldClose?(sender) ?? true }
        Task {
            if await model.files.prepareToLeave() {
                // Don't Save discards edits even if the editor is reopened later.
                model.discardChanges()
                allowCloseOnce = true
                sender.performClose(nil)
            }
        }
        return false
    }
    // AppKit asks these NSObject delegate-routing questions on its UI thread.
    nonisolated override func responds(to selector: Selector!) -> Bool {
        MainActor.assumeIsolated { super.responds(to: selector) || previous?.responds(to: selector) == true }
    }
    nonisolated override func forwardingTarget(for selector: Selector!) -> Any? {
        // This Objective-C forwarding callback stays on the UI thread. Carry the
        // retained native reference without declaring NSWindowDelegate Sendable.
        let address = MainActor.assumeIsolated {
            previous.map { UInt(bitPattern: Unmanaged.passRetained($0 as AnyObject).toOpaque()) }
        }
        guard let address, let pointer = UnsafeRawPointer(bitPattern: address) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeRetainedValue()
    }
}

final class ProjectAppDelegate: NSObject, NSApplicationDelegate {
    private weak var model: AppModel?
    private var pendingOpen: URL?
    private var showControl: (() -> Void)?
    private var isReady = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        // File-open events can precede launch completion. Creating an MTKView
        // must wait for AppKit and SwiftUI to finish initializing the app.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isReady = true
            self.openPendingProject()
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func connect(_ model: AppModel, showControl: @escaping () -> Void) {
        self.model = model
        self.showControl = showControl
        openPendingProject()
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        pendingOpen = url
        openPendingProject()
    }
    private func openPendingProject() {
        guard isReady, model != nil, let url = pendingOpen else { return }
        pendingOpen = nil
        openProject(url)
    }
    private func openProject(_ url: URL) {
        showControl?()
        guard let model else { return }
        Task { await model.files.openProject(url) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model, model.isDirty || model.files.isBusy else { return .terminateNow }
        Task { sender.reply(toApplicationShouldTerminate: await model.files.prepareToLeave()) }
        return .terminateLater
    }
}
