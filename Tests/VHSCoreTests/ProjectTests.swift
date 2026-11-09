import Foundation
import Testing
@testable import VHSCore

private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VHS-tests-\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

@Test func projectRoundTrip() throws {
    let project = ProjectDocument(name: "Set One", scene: .init(color: .init(red: 0.2, green: 0.4, blue: 0.6), seed: 47))
    #expect(try ProjectCodec.decode(ProjectCodec.encode(project)) == project)
}

@Test(arguments: ["", " ", ".", "..", "a/b", "a:b", "a\\b", "a\u{0000}b", String(repeating: "x", count: 121)])
func invalidProjectNames(_ name: String) {
    #expect(throws: ProjectError.invalidName) { try ProjectDocument.validatedName(name) }
}

@Test func corruptAndUnsupportedDocuments() throws {
    #expect(throws: ProjectError.corrupt) { try ProjectCodec.decode(Data("not JSON".utf8)) }
    #expect(throws: ProjectError.unsupportedVersion(99)) {
        try ProjectCodec.decode(Data(#"{"schemaVersion":99}"#.utf8))
    }
    #expect(throws: ProjectError.unsupportedVersion(0)) {
        try ProjectCodec.decode(Data(#"{"schemaVersion":0}"#.utf8))
    }
    #expect(throws: ProjectError.tooLarge) { try ProjectCodec.decode(Data(repeating: 32, count: ProjectCodec.maximumBytes + 1)) }
    let data = try ProjectCodec.encode(.init())
    var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var scene = try #require(json["scene"] as? [String: Any])
    var parameters = try #require(scene["parameters"] as? [String: Any])
    parameters["source.solid.red"] = ["type": "number", "value": 2]
    scene["parameters"] = parameters
    json["scene"] = scene
    #expect(throws: ProjectError.invalidValues) { try ProjectCodec.decode(JSONSerialization.data(withJSONObject: json)) }
}

@Test func atomicSavePreservesValidFileOnFailure() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("Show.vhsproject")
    let store = ProjectStore()
    let original = ProjectDocument(name: "Show")
    try store.write(original, to: file)
    let originalBytes = try Data(contentsOf: file)
    enum Injected: Error { case writeFailure }
    #expect(throws: Injected.self) {
        try store.write(original.named("Changed"), to: file, beforeCommit: { throw Injected.writeFailure })
    }
    #expect(try Data(contentsOf: file) == originalBytes)
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["Show.vhsproject"])
    let updated = ProjectDocument(id: original.id, name: "Show", scene: .init(seed: 999))
    try store.write(updated, to: file)
    #expect(try store.read(from: file) == updated)
}

@Test func failingWriteAndCommitLeaveExistingDataIntact() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ProjectStore()
    let file = directory.appendingPathComponent("Original.vhsproject")
    try store.write(.init(name: "Original"), to: file)
    let original = try Data(contentsOf: file)
    #expect(throws: (any Error).self) {
        try store.write(.init(), to: directory.appendingPathComponent("missing/Target.vhsproject"))
    }
    let nonFile = directory.appendingPathComponent("directory.vhsproject")
    try FileManager.default.createDirectory(at: nonFile, withIntermediateDirectories: true)
    #expect(throws: (any Error).self) { try store.write(.init(), to: nonFile) }
    #expect(try Data(contentsOf: file) == original)
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).allSatisfy { !$0.hasPrefix(".vhs-save-") })
}

@Test func renamePreservesDataAndRefusesCollision() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ProjectStore()
    let file = directory.appendingPathComponent("Before.vhsproject")
    let project = ProjectDocument(name: "Before", scene: .init(seed: 16))
    try store.write(project, to: file)
    let renamed = try store.rename(file, to: "After")
    #expect(!FileManager.default.fileExists(atPath: file.path))
    #expect(try store.read(from: renamed) == project.named("After"))
    let other = directory.appendingPathComponent("Other.vhsproject")
    try store.write(.init(name: "Other"), to: other)
    let bytes = try Data(contentsOf: other)
    #expect(throws: (any Error).self) { try store.rename(renamed, to: "Other") }
    #expect(try Data(contentsOf: other) == bytes)
    #expect(FileManager.default.fileExists(atPath: renamed.path))
}

@Test func dirtyTrackingAndConcurrentSaveSnapshot() throws {
    let original = ProjectDocument(name: "Set")
    var session = ProjectSession(document: original)
    #expect(!session.isDirty && session.needsSave)
    session.send(.setParameter(.solidRed, 0.8))
    #expect(session.isDirty)
    session.undo(); #expect(!session.isDirty)
    session.redo()
    let snapshotBeingSaved = session.document
    session.send(.setParameter(.solidGreen, 0.7))
    let file = URL(fileURLWithPath: "/tmp/Set.vhsproject")
    session.recordSave(snapshotBeingSaved, to: file)
    #expect(session.isDirty && session.fileURL == file)
    session.undo(); #expect(!session.isDirty)
    session.recordRename(name: "New Set", fileURL: file.deletingLastPathComponent().appendingPathComponent("New Set.vhsproject"))
    #expect(!session.isDirty && session.name == "New Set")
    session.send(.setParameter(.solidBlue, 0.9))
    session.recordRename(name: "Another Set", fileURL: file)
    #expect(session.isDirty)
    let reopened = ProjectSession(document: session.document, fileURL: file)
    #expect(!reopened.isDirty && !reopened.history.canUndo && !reopened.history.canRedo)
}

@Test func caseOnlyRenameAndUnsavedRenameValidation() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("Show.vhsproject")
    let store = ProjectStore()
    try store.write(.init(name: "Show"), to: file)
    let renamed = try store.rename(file, to: "SHOW")
    #expect(try store.read(from: renamed).name == "SHOW")
    var session = ProjectSession()
    try session.renameUnsaved(to: "Night Set")
    #expect(session.isDirty && session.name == "Night Set")
    #expect(throws: ProjectError.invalidName) { try session.renameUnsaved(to: "bad/name") }
    #expect(session.name == "Night Set")
}
