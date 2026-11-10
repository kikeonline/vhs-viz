import Foundation
import Darwin

@_cdecl("vhs_signal_resource_anchor") public nonisolated func signalResourceAnchor() {}

enum SignalResources {
    static var tokens: URL {
        // A DAW owns Bundle.main. Locate our dylib's adjacent plug-in resources first;
        // SwiftPM's generated accessor is only correct for CLI/standalone development.
        var info = Dl_info()
        let address = unsafeBitCast(signalResourceAnchor as @convention(c) () -> Void, to: UnsafeRawPointer.self)
        if dladdr(address, &info) != 0, let path = info.dli_fname {
            let binary = URL(fileURLWithPath: String(cString: path))
            let candidate = binary.deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Resources/VHS_VHSSignal.bundle")
            if let url = Bundle(url: candidate)?.url(forResource: "tokens", withExtension: "json") { return url }
        }
        return Bundle.module.url(forResource: "tokens", withExtension: "json")!
    }
}
