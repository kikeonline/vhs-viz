import Foundation
import VHSRealtime

/// Retaining the bridge keeps the queue alive across worker drain and UI teardown.
public actor HostAudioWorker {
    private let address: UInt
    private let analyzer: AudioAnalyzer
    public init(bridgeAddress: UInt) throws {
        address = bridgeAddress; analyzer = try AudioAnalyzer()
        vhs_bridge_retain(OpaquePointer(bitPattern:address)!)
    }
    deinit { vhs_bridge_release(OpaquePointer(bitPattern:address)!) }
    public func drain() throws -> AudioSignals {
        try analyzer.drain(vhs_bridge_audio(OpaquePointer(bitPattern:address)!))
        return analyzer.signals
    }
}
