import AppKit
import SwiftUI
import VHSSignal
import VHSCore
import VHSDevices
import VHSInput

enum InputsVerification {
    private enum Failure: Error { case documentChanged }
    static func run(_ model: AppModel) throws {
        let original = model.document, history = model.history
        model.inputs.chooseAudio("fixture-interface")
        model.inputs.chooseChannels(.init(left: 1, right: 2))
        model.inputs.chooseMIDI(1234); model.inputs.chooseMIDIChannel(3)
        model.inputs.chooseSource(.system)
        var snapshot = InputSnapshot()
        snapshot.audio.ready = true; snapshot.audio.rms = 0.5; snapshot.heldNotes = 1
        model.inputs.fixture(snapshot, audioRunning: true, midiRunning: true)
        guard model.document == original, model.history.scene == history.scene,
              model.history.canUndo == history.canUndo else { throw Failure.documentChanged }
        model.inputs.stopAudio(); model.inputs.stopMIDI()
        model.inputs.fixture(InputSnapshot(), audioRunning: false, midiRunning: false)
        Verification.log("PASS input selections and transient values leave document/history unchanged (isolated fixture)")
    }

    static func snapshots(_ model: AppModel, control: NSWindow, directory: String, systemAudio: Bool = false) async throws {
        let input = model.inputs
        input.chooseAudio("fixture-interface"); input.chooseChannels(.init(left: 0, right: 1))
        input.chooseMIDI(1234)
        if systemAudio { input.chooseSource(.system) }
        let physicalCases: [(String, InputStatus, SystemAudioStatus)] = [
            ("off", .off, .off), ("listening", .active, .off), ("silent", .silent, .off),
            ("waiting", .waiting, .off), ("denied", .denied, .off), ("restricted", .restricted, .off),
            ("unavailable", .unavailable, .off), ("channels-unavailable", .invalidChannels, .off), ("error", .failed(-1), .off)]
        let systemCases: [(String, InputStatus, SystemAudioStatus)] = SystemAudioStatus.allCases.map { state in
            (String(describing: state), state == .capturing ? .active : state == .denied ? .denied : state == .failed ? .failed(-1) : .off, state)
        } + [("silent", .silent, .capturing), ("no-data", .waiting, .capturing)]
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: Layout.inputWidth, height: Layout.inputMaxHeight), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.title = "VHS Inputs fixture"
        defer { window.contentView = nil; window.close(); NSApp.appearance = nil }
        for (mode, appearance) in SignalSnapshots.appearances {
            NSApp.appearance = NSAppearance(named: appearance)
            for (name, status, systemState) in systemAudio ? systemCases : physicalCases {
                var snapshot = InputSnapshot()
                snapshot.audioDevices = [.init(id: "fixture-interface", name: "Long interface name — 32-channel stage input and monitor return", objectID: 1, channels: 32, sampleRate: 48_000)]
                snapshot.midiSources = [.init(id: 1234, name: "Long controller name — hardware and virtual performance source", endpoint: 2)]
                snapshot.audioStatus = status
                snapshot.systemStatus = systemState
                snapshot.midiStatus = status == .active ? .active : status == .unavailable ? .unavailable : .off
                if status == .active || status == .silent {
                    snapshot.audio.ready = true
                    if status == .active {
                        snapshot.audio.rms = 0.35; snapshot.audio.peak = 0.9
                        snapshot.audio.low = 0.3; snapshot.audio.mid = 0.15; snapshot.audio.high = 0.07; snapshot.audio.transient = 0.6
                        var decoder = MIDIDecoder()
                        for byte: UInt8 in [0x92, 60, 100] { if let event = decoder.accept(byte, sampleTime: 100, offset: 0) { snapshot.lastMIDI = event } }
                        snapshot.heldNotes = 1
                    }
                }
                if status == .unavailable { snapshot.audioDevices = []; snapshot.midiSources = [] }
                if case .failed = status { snapshot.audioDrops = 5; snapshot.audio.invalidSamples = 2; snapshot.audio.clipped = true; snapshot.midiLosses = 1 }
                input.fixture(snapshot, audioRunning: systemAudio ? !systemState.isTerminal : [.active, .silent, .waiting, .unavailable].contains(status), midiRunning: status == .active || status == .unavailable)
                window.contentView = NSHostingView(rootView: InputsView(inputs: input))
                control.orderOut(nil); NSApp.activate(); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(nil)
                try await Task.sleep(for: .milliseconds(120))
                let path = "\(directory)/\(systemAudio ? "system-audio" : "inputs")-\(name)-\(mode)"
                GridProbes.shared.write(to: path + "-layout.json", window: window.contentLayoutRect.size)
                try Verification.capture(window, to: path + ".png")
                if let scroll = window.contentView.flatMap({ scrollView($0) }), let document = scroll.documentView {
                    document.scroll(NSPoint(x: 0, y: document.bounds.maxY)); scroll.reflectScrolledClipView(scroll.contentView)
                    NSApp.activate(); window.makeKeyAndOrderFront(nil)
                    try await Task.sleep(for: .milliseconds(100))
                    GridProbes.shared.write(to: path + "-bottom-layout.json", window: window.contentLayoutRect.size)
                    try Verification.capture(window, to: path + "-bottom.png")
                }
            }
            window.orderOut(nil); control.makeKeyAndOrderFront(nil)
            for (name, size) in [("default", NSSize(width: Layout.defaultWidth, height: Layout.defaultHeight)),
                                 ("minimum", NSSize(width: Layout.minWidth, height: Layout.minHeight)),
                                 ("wide", NSSize(width: 1440, height: 900))] {
                control.setContentSize(size); control.makeKeyAndOrderFront(nil)
                try await Task.sleep(for: .milliseconds(120))
                let path = "\(directory)/inputs-toolbar-\(name)-\(mode)"
                GridProbes.shared.write(to: path + "-layout.json", window: size)
                try Verification.capture(control, to: path + ".png")
            }
        }
        input.fixture(InputSnapshot(), audioRunning: false, midiRunning: false)
    }
    private static func scrollView(_ view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { scrollView($0) }.first
    }
}
