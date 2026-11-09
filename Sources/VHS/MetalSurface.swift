import AppKit
import MetalKit
import SwiftUI
import VHSRenderer

struct MetalSurface: NSViewRepresentable {
    let model: AppModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: model.renderer?.device)
        view.colorPixelFormat = MetalRenderer.pixelFormat
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        view.preferredFramesPerSecond = 60
        view.framebufferOnly = true
        view.delegate = context.coordinator
        view.isPaused = true
        model.registerSurface(view)
        view.setAccessibilityLabel("Live scene")
        return view
    }
    func updateNSView(_ view: MTKView, context: Context) {}
    static func dismantleNSView(_ view: MTKView, coordinator: Coordinator) {
        coordinator.model.unregisterSurface(view)
        view.isPaused = true; view.delegate = nil
    }
    @MainActor final class Coordinator: NSObject, MTKViewDelegate {
        private(set) var drawableFrameCount = 0
        private var hasFailed = false
        let model: AppModel
        init(model: AppModel) { self.model = model }
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        func draw(in view: MTKView) {
            guard !hasFailed, let drawable = view.currentDrawable, let renderer = model.renderer else { return }
            drawableFrameCount += 1
            do { try renderer.draw(model.frame, drawable: drawable) }
            catch { hasFailed = true; model.errorMessage = error.localizedDescription }
        }
    }
}

final class OutputWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private(set) var window: NSWindow?
    init(model: AppModel) { self.model = model }
    func show() {
        if let window { window.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 540),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "VHS Output"
        window.minSize = NSSize(width: 320, height: 180)
        window.collectionBehavior = [.fullScreenPrimary]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MetalSurface(model: model).ignoresSafeArea())
        window.delegate = self
        window.center(); self.window = window
        window.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        // Release the view/delegate so closing the output stops its display loop.
        window?.contentView = nil; window = nil
    }
}
