import Foundation
import Darwin

/// Synchronous file primitives; the app calls these through ProjectIO's actor.
public struct ProjectStore: Sendable {
    public init() {}
    public func read(from url: URL) throws -> ProjectDocument {
        guard url.isFileURL else { throw ProjectError.corrupt }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= ProjectCodec.maximumBytes else { throw ProjectError.tooLarge }
        let document = try ProjectCodec.decode(Data(contentsOf: url))
        // Finder and Rename may change a filename independently of serialized title.
        let name = try ProjectDocument.validatedName(url.deletingPathExtension().lastPathComponent)
        return document.named(name)
    }
    public func write(_ document: ProjectDocument, to url: URL,
                      beforeCommit: () throws -> Void = {}) throws {
        let data = try ProjectCodec.encode(document)
        let temp = url.deletingLastPathComponent().appendingPathComponent(".vhs-save-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temp) }
        try data.write(to: temp, options: .withoutOverwriting)
        let handle = try FileHandle(forWritingTo: temp)
        do { try handle.synchronize(); try handle.close() }
        catch { try? handle.close(); throw error }
        try beforeCommit()
        // Same-directory POSIX rename atomically replaces the directory entry.
        // Until this succeeds, the target remains untouched.
        let status = temp.withUnsafeFileSystemRepresentation { source in
            url.withUnsafeFileSystemRepresentation { destination in Darwin.rename(source!, destination!) }
        }
        guard status == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }
    public func rename(_ url: URL, to name: String) throws -> URL {
        let name = try ProjectDocument.validatedName(name)
        let destination = url.deletingLastPathComponent().appendingPathComponent(name).appendingPathExtension("vhsproject")
        guard destination != url else { return url }
        // Foundation's move refuses an existing destination rather than replacing it.
        do { try FileManager.default.moveItem(at: url, to: destination) }
        catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
            throw ProjectError.destinationExists
        }
        return destination
    }
}

/// File work cannot run on the app's main actor, even though its caller is UI code.
public actor ProjectIO {
    private let store = ProjectStore()
    public init() {}
    public func read(from url: URL) throws -> ProjectDocument { try store.read(from: url) }
    public func write(_ document: ProjectDocument, to url: URL) throws { try store.write(document, to: url) }
    public func rename(_ url: URL, to name: String) throws -> URL { try store.rename(url, to: name) }
}
