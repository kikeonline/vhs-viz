import AppKit
import VHSPluginUI

if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--state-fixture" {
    do { try writePluginGraphFixture(to:CommandLine.arguments[2]); print("PASS generated graph state fixture"); exit(0) }
    catch { fputs("FAIL graph fixture: \(error)\n",stderr); exit(1) }
}
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
