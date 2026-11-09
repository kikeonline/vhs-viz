import AppKit
import VHSPluginUI

let app = NSApplication.shared
app.setActivationPolicy(.regular)
Task { @MainActor in
    do {
        try await runPluginProbe(folder: CommandLine.arguments.dropFirst().first ?? "/tmp/VHS-plugin-shots")
        print("PLUGIN SELFTEST done")
        exit(0)
    } catch {
        fputs("PLUGIN SELFTEST FAIL: \(error)\n", stderr)
        exit(1)
    }
}
app.run()
