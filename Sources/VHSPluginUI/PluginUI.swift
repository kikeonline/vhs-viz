import AppKit
import SwiftUI
import MetalKit
import Observation
import VHSCore
import VHSRenderer
import VHSRealtime

@Observable final class PluginRuntime: NSObject, NSWindowDelegate {
    let bridge: OpaquePointer
    let render: RenderSession
    var red = 0.24
    var green = 0.08
    var blue = 0.62
    var peak = 0.0
    var velocity = 0.0
    var cc = 0.0
    var tempo = 0.0
    var playing = false
    var learning = false
    var candidate: VHSInput?
    var learnedChannel: Int32?
    var learnedController: Int32?
    var learnedValue = 0.0
    var dropped: UInt32 = 0
    var error: String?
    @ObservationIgnored var output: NSWindow?
    @ObservationIgnored var timer: Timer?
    @ObservationIgnored var notes = [Double](repeating: 0, count: 16 * 128)
    @ObservationIgnored var lastBlock = ContinuousClock.now
    init(_ bridge: OpaquePointer, shaderURL: URL? = nil) throws {
        self.bridge = bridge
        render = try RenderSession(shaderURL: shaderURL)
        vhs_bridge_retain(bridge)
        super.init()
        timer = Timer(timeInterval: 1.0 / 60, repeats: true) { @Sendable [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        tick()
    }
    func stop() {
        timer?.invalidate(); timer = nil
        output?.contentView = nil; output?.close(); output = nil
    }
    isolated deinit { vhs_bridge_release(bridge) }
    func tick() {
        red = vhs_bridge_get(bridge, 0); green = vhs_bridge_get(bridge, 1); blue = vhs_bridge_get(bridge, 2)
        cc = vhs_bridge_get(bridge, 3)
        var event = VHSInput()
        let before = vhs_bridge_dropped(bridge)
        for _ in 0..<256 {
            guard vhs_bridge_pop(bridge, &event) != 0 else { break }
            switch event.kind {
            case 0:
                peak = event.value; tempo = event.flags & 4 != 0 ? event.tempo : 0
                playing = event.flags & 2 != 0; lastBlock = .now
            case 1, 2:
                if (0..<16).contains(event.channel), (0..<128).contains(event.number) {
                    notes[Int(event.channel) * 128 + Int(event.number)] = event.kind == 1 ? event.value : 0
                }
            case 3:
                if learning, candidate == nil { candidate = event; learning = false }
                if event.channel == learnedChannel && event.number == learnedController { learnedValue = event.value }
            case 4: notes = Array(repeating: 0, count: notes.count); peak = 0
            default: break
            }
        }
        dropped = vhs_bridge_dropped(bridge)
        // Overflow invalidates held-note state, including retained queued note-ons.
        if dropped != before || dropped != lastDropped || lastBlock.duration(to: .now) > .milliseconds(250) {
            notes = Array(repeating: 0, count: notes.count); peak = 0; learnedValue = 0; playing = false
        }
        lastDropped = dropped
        velocity = notes.max() ?? 0
        // Prototype bindings: audio peak -> red; held velocity -> green; host CC1 -> blue.
        // Persisted base values remain separate from transient input.
        let scene = SceneSnapshot(color: .init(red: min(1, red + peak), green: min(1, green + velocity), blue: min(1, blue + (learnedController == nil ? cc : learnedValue))))
        render.update(scene)
    }
    @ObservationIgnored private var lastDropped: UInt32 = 0
    func edit(_ id: UInt32, _ value: Double, _ phase: UInt32) { vhs_bridge_edit(bridge, id, value, phase) }
    func showOutput() {
        if let output { output.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: Layout.previewWidth, height: Layout.previewHeight),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "VHS Prototype Output"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PluginSurface(runtime: self))
        window.delegate = self; output = window
        window.center(); window.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) { output?.contentView = nil; output = nil }
}

struct PluginEditor: View {
    let runtime: PluginRuntime
    var body: some View {
        HStack(alignment: .top, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.xl) {
                Text("Solid").font(.headline).gridProbe("plugin-source", area: "plugin-controls")
                slider("Red", id: 0, value: runtime.red)
                slider("Green", id: 1, value: runtime.green)
                slider("Blue", id: 2, value: runtime.blue)
                Button("Show Output", systemImage: "rectangle.on.rectangle") { runtime.showOutput() }
                    .help("Open this instance’s visual output")
                    .accessibilityLabel("Show Output")
                Text("Audio → Red · Velocity → Green · CC1 → Blue").font(.caption).foregroundStyle(.secondary)
                Button(runtime.learning ? "Cancel Learn" : "Learn Blue") {
                    runtime.candidate = nil; runtime.learning.toggle()
                }.accessibilityLabel(runtime.learning ? "Cancel Learn" : "Learn Blue")
                if let candidate = runtime.candidate {
                    Text("Channel \(candidate.channel + 1) · CC\(candidate.number)")
                    HStack(spacing: Space.sm) {
                        Button("Confirm") {
                            runtime.learnedChannel = candidate.channel; runtime.learnedController = candidate.number
                            runtime.learnedValue = candidate.value; runtime.candidate = nil
                        }
                        Button("Cancel") { runtime.candidate = nil }
                    }
                } else if runtime.learning {
                    Text("Move a MIDI controller…").foregroundStyle(.secondary)
                } else if let cc = runtime.learnedController, let channel = runtime.learnedChannel {
                    Text("Blue: Channel \(channel + 1) · CC\(cc)").foregroundStyle(.secondary)
                    Button("Clear Learn") {
                        runtime.learnedChannel = nil; runtime.learnedController = nil; runtime.learnedValue = 0
                    }
                }
                Text("Peak \(runtime.peak, specifier: "%.3f") · Velocity \(runtime.velocity, specifier: "%.3f") · CC1 \(runtime.cc, specifier: "%.3f")")
                    .monospacedDigit().font(.caption)
                Text(runtime.tempo > 0 ? "\(runtime.tempo.formatted()) BPM · \(runtime.playing ? "Playing" : "Stopped")" : "No host tempo")
                    .foregroundStyle(.secondary)
                if runtime.dropped > 0 { Text("Input overflow: \(runtime.dropped)").foregroundStyle(.secondary) }
                if let error = runtime.error { Text(error).foregroundStyle(.secondary) }
            }.frame(width: Layout.controlWidth)
                .gridArea("plugin-controls", inset: 0)
                .gridProbe("plugin-controls", area: "plugin-editor", edge: nil)
            PluginSurface(runtime: runtime).aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Layout.previewRadius))
                .gridProbe("plugin-preview", area: "plugin-editor", edge: nil)
        }.padding(Space.margin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .gridArea("plugin-editor")
    }
    private func slider(_ title: String, id: UInt32, value: Double) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            LabeledContent(title, value: value.formatted(.number.precision(.fractionLength(2))))
            Slider(value: Binding(get: { vhs_bridge_get(runtime.bridge, id) }, set: { runtime.edit(id, $0, 1) }), in: 0...1,
                   onEditingChanged: { runtime.edit(id, vhs_bridge_get(runtime.bridge, id), $0 ? 0 : 2) })
                .accessibilityLabel(title)
        }.gridProbe("plugin-\(id)", area: "plugin-controls")
    }
}
struct PluginSurface: NSViewRepresentable {
    let runtime: PluginRuntime
    func makeCoordinator() -> SurfaceDelegate { SurfaceDelegate(runtime) }
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: runtime.render.renderer.device)
        view.colorPixelFormat = MetalRenderer.pixelFormat
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        view.framebufferOnly = true; view.isPaused = true
        view.delegate = context.coordinator
        runtime.render.register(view)
        view.setAccessibilityLabel("Live scene")
        return view
    }
    func updateNSView(_ view: MTKView, context: Context) {}
    static func dismantleNSView(_ view: MTKView, coordinator: SurfaceDelegate) {
        coordinator.runtime.render.unregister(view); view.delegate = nil
    }
    final class SurfaceDelegate: NSObject, MTKViewDelegate {
        let runtime: PluginRuntime
        init(_ runtime: PluginRuntime) { self.runtime = runtime }
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable else { return }
            do { try runtime.render.renderer.draw(runtime.render.frame, drawable: drawable) }
            catch { runtime.error = error.localizedDescription }
        }
    }
}
// Called only from host control/UI operations. Audio never enters Swift.
@_cdecl("vhs_ui_create") public func createRuntime(_ bridge: OpaquePointer, _ shaderPath: UnsafePointer<CChar>) -> UnsafeMutableRawPointer? {
    guard Thread.isMainThread, let runtime = try? PluginRuntime(bridge, shaderURL: URL(fileURLWithPath: String(cString: shaderPath))) else { return nil }
    return Unmanaged.passRetained(runtime).toOpaque()
}
@_cdecl("vhs_ui_attach") public func attachEditor(_ handle: UnsafeMutableRawPointer, _ parent: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    guard Thread.isMainThread else { return nil }
    let runtime = Unmanaged<PluginRuntime>.fromOpaque(handle).takeUnretainedValue()
    let parentView = Unmanaged<NSView>.fromOpaque(parent).takeUnretainedValue()
    let view = NSHostingView(rootView: PluginEditor(runtime: runtime))
    view.frame = parentView.bounds; view.autoresizingMask = [.width, .height]
    parentView.addSubview(view)
    return Unmanaged.passRetained(view).toOpaque()
}
@_cdecl("vhs_ui_detach") public func detachEditor(_ view: UnsafeMutableRawPointer) {
    guard Thread.isMainThread else { return }
    Unmanaged<NSView>.fromOpaque(view).takeRetainedValue().removeFromSuperview()
}
@_cdecl("vhs_ui_destroy") public nonisolated func destroyRuntime(_ handle: UnsafeMutableRawPointer) {
    // A host may release its final component reference on a worker thread.
    let address = UInt(bitPattern: handle)
    let teardown: @MainActor @Sendable () -> Void = {
        let runtime = Unmanaged<PluginRuntime>.fromOpaque(UnsafeMutableRawPointer(bitPattern: address)!).takeRetainedValue()
        runtime.stop()
    }
    if Thread.isMainThread { MainActor.assumeIsolated { teardown() } }
    else { DispatchQueue.main.async { teardown() } }
}
