import Foundation

/// Document and history ownership, independent of windows and file dialogs.
public struct ProjectSession: Sendable {
    public private(set) var history: SceneHistory
    public private(set) var name: String
    public let id: UUID
    public private(set) var fileURL: URL?
    public private(set) var graphLayout: GraphLayout
    private var baseline: ProjectDocument
    public var document: ProjectDocument { .init(id: id, name: name, scene: history.scene, graphLayout: graphLayout) }
    public var isDirty: Bool { document != baseline }
    public var needsSave: Bool { fileURL == nil || isDirty }

    public init(document: ProjectDocument = .init(), fileURL: URL? = nil) {
        id = document.id; name = document.name
        history = SceneHistory(scene: document.scene)
        graphLayout = document.graphLayout
        baseline = document; self.fileURL = fileURL
    }
    public mutating func discardChanges() {
        history = SceneHistory(scene: baseline.scene)
        name = baseline.name
        graphLayout = baseline.graphLayout
    }
    public mutating func setGraphLayout(_ layout: GraphLayout) { if (try? layout.validate()) != nil { graphLayout = layout } }
    public mutating func beginEdit() { history.beginEdit() }
    public mutating func endEdit() { history.endEdit() }
    public mutating func send(_ action: SceneAction) { history.send(action) }
    public mutating func undo() { history.undo() }
    public mutating func redo() { history.redo() }
    public mutating func renameUnsaved(to name: String) throws {
        self.name = try ProjectDocument.validatedName(name)
    }
    public mutating func recordRename(name: String, fileURL: URL) {
        self.name = name; self.fileURL = fileURL
        // The filename itself persists this change. Do not clear scene edits.
        baseline = baseline.named(name)
    }
    public mutating func recordSave(_ saved: ProjectDocument, to url: URL) {
        precondition(saved.id == id)
        // A save captures an earlier snapshot; edits made during I/O stay dirty.
        baseline = saved; name = saved.name; fileURL = url
    }
}
