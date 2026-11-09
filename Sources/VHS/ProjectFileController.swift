import AppKit
import Observation
import VHSCore

/// Owns user transitions and dialogs. No model is replaced until I/O and consent succeed.
@Observable final class ProjectFileController {
    @ObservationIgnored private unowned let model: AppModel
    @ObservationIgnored let io: ProjectIO
    @ObservationIgnored var dialogs: any ProjectDialogs
    private(set) var isBusy = false { didSet { model.refreshMenu() } }
    private(set) var blocksSceneEditing = false { didSet { model.refreshMenu() } }
    var isRenaming = false { didSet { model.refreshMenu() } }
    var renameError: String?
    var commandsEnabled: Bool { !isBusy && !isRenaming }

    init(model: AppModel, io: ProjectIO = ProjectIO(), dialogs: any ProjectDialogs = NativeProjectDialogs()) {
        self.model = model; self.io = io; self.dialogs = dialogs
    }
    func newProject() async {
        guard commandsEnabled else { return }
        isBusy = true; blocksSceneEditing = true
        defer { blocksSceneEditing = false; isBusy = false }
        do {
            if try await resolveUnsaved() { model.replaceProject(.init()) }
        } catch { await report(error, action: "Create Project") }
    }
    func openProject(_ providedURL: URL? = nil) async {
        guard commandsEnabled else { return }
        isBusy = true; blocksSceneEditing = true
        defer { blocksSceneEditing = false; isBusy = false }
        guard let url = await providedURLOrPanel(providedURL) else { return }
        do {
            _ = try await io.read(from: url)
            if try await resolveUnsaved() {
                // A Save in the confirmation may have replaced this same file.
                let committed = try await io.read(from: url)
                model.replaceProject(committed, fileURL: url)
            }
        } catch { await report(error, action: "Open Project") }
    }
    func saveProject(asNewFile: Bool = false, to providedURL: URL? = nil) async -> Bool {
        guard commandsEnabled else { return false }
        isBusy = true; defer { isBusy = false }
        do { return try await saveNow(asNewFile: asNewFile, providedURL: providedURL) }
        catch { await report(error, action: "Save Project"); return false }
    }
    func beginRename() {
        guard commandsEnabled else { return }
        renameError = nil; isRenaming = true
    }
    func renameProject(to proposedName: String) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true; defer { isBusy = false }
        do {
            let name = try ProjectDocument.validatedName(proposedName)
            if let currentURL = model.fileURL {
                let url = try await io.rename(currentURL, to: name)
                model.recordRename(name: name, fileURL: url)
            } else { try model.renameUnsaved(to: name) }
            isRenaming = false; renameError = nil
            return true
        } catch { renameError = error.localizedDescription; return false }
    }
    /// Used by both the editor's close delegate and the app's quit delegate.
    func prepareToLeave() async -> Bool {
        guard commandsEnabled else { return false }
        isBusy = true; blocksSceneEditing = true
        defer { blocksSceneEditing = false; isBusy = false }
        do { return try await resolveUnsaved() }
        catch { await report(error, action: "Save Project"); return false }
    }
    private func resolveUnsaved() async throws -> Bool {
        guard model.isDirty else { return true }
        switch await dialogs.confirmUnsaved(name: model.projectName) {
        case .cancel: return false
        case .discard: return true
        case .save:
            let saved = try await saveNow()
            // Edits made while the save was in flight must not be silently lost.
            return saved && !model.isDirty
        }
    }
    private func saveNow(asNewFile: Bool = false, providedURL: URL? = nil) async throws -> Bool {
        model.endEdit()
        let destination: URL?
        if let providedURL { destination = providedURL }
        else if !asNewFile, let existing = model.fileURL { destination = existing }
        else { destination = await dialogs.chooseSaveURL(name: model.projectName, currentURL: model.fileURL) }
        guard var url = destination else { return false }
        if url.pathExtension.isEmpty { url.appendPathExtension("vhsproject") }
        let name = try ProjectDocument.validatedName(url.deletingPathExtension().lastPathComponent)
        let captured = model.document.named(name)
        try await io.write(captured, to: url)
        model.recordSave(captured, to: url)
        return true
    }
    private func providedURLOrPanel(_ url: URL?) async -> URL? {
        if let url { return url }
        return await dialogs.chooseOpenURL()
    }
    private func report(_ error: any Error, action: String) async {
        await dialogs.showError(title: "Unable to \(action)", message: error.localizedDescription)
    }
}
