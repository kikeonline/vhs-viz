import Foundation
import Observation
import VHSCore

public enum GraphBuildStatus: Equatable, Sendable {
    case idle, compiling, ready, failed(GraphDiagnostic)
    public var message: String {
        switch self {
        case .idle: "Ready"
        case .compiling: "Compiling… Last valid render continues."
        case .ready: "Ready"
        case let .failed(error): error.localizedDescription + " Last valid render continues."
        }
    }
}
@MainActor @Observable public final class GraphBuildCoordinator {
    public private(set) var status: GraphBuildStatus = .idle
    @ObservationIgnored private var requested: ShaderGraph?
    @ObservationIgnored private var task: Task<Void,Never>?
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var pending: CompiledGraph?
    @ObservationIgnored private let compile: @Sendable (ShaderGraph) async throws -> CompiledGraph
    public init(compile: @escaping @Sendable (ShaderGraph) async throws -> CompiledGraph) { self.compile = compile }
    public func request(_ graph: ShaderGraph) {
        guard graph != requested else { return }
        task?.cancel(); generation &+= 1
        let token = generation; requested = graph; pending = nil; status = .compiling
        let compile = compile
        task = Task { [weak self] in
            do {
                try await Task.sleep(for:.milliseconds(80))
                let result = try await compile(graph)
                guard let self, token == generation, !Task.isCancelled else { return }
                pending = result; status = .ready
            } catch is CancellationError {} catch {
                guard let self, token == generation, !Task.isCancelled else { return }
                status = .failed(error as? GraphDiagnostic ?? GraphDiagnostic(error.localizedDescription))
            }
        }
    }
    /// Only the frame timer consumes a successful executable, never an async callback.
    public func takeReady(for graph: ShaderGraph) -> CompiledGraph? {
        guard pending?.graph == graph else { return nil }
        defer { pending = nil }
        return pending
    }
    public func cancel() {
        guard requested != nil else { return }
        task?.cancel(); task = nil; generation &+= 1; requested = nil; pending = nil; status = .idle
    }
}
