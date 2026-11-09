import AppKit
import VHSCore
import SwiftUI

enum SourceSnapshots {
    static func run(_ model: AppModel, control: NSWindow, directory: String) async throws {
        func scrollView(_ view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView { return scroll }
            return view.subviews.lazy.compactMap { scrollView($0) }.first
        }
        model.output.window?.performClose(nil)
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named:mode == "light" ? .aqua : .darkAqua)
            for source in SourceKind.allCases {
                model.replaceProject(.init(scene:.init(source:source)))
                for (suffix,size) in [("",NSSize(width:Layout.defaultWidth,height:Layout.defaultHeight)),
                                      ("-minimum",NSSize(width:Layout.minWidth,height:Layout.minHeight))] {
                    control.setContentSize(size)
                    NSApp.activate(); control.makeKeyAndOrderFront(nil); control.makeFirstResponder(nil)
                    try await Task.sleep(for:.milliseconds(400))
                    let path = "\(directory)/source-\(source.rawValue)\(suffix)-\(mode)"
                    GridProbes.shared.write(to:path+"-layout.json",window:size)
                    try Verification.capture(control,to:path+".png")
                }
                if source != .solid, let scroll = control.contentView.flatMap({ scrollView($0) }), let document = scroll.documentView {
                    document.scroll(NSPoint(x:0,y:document.bounds.maxY))
                    scroll.reflectScrolledClipView(scroll.contentView)
                    NSApp.activate(); control.makeKeyAndOrderFront(nil)
                    try await Task.sleep(for:.milliseconds(250))
                    let path = "\(directory)/source-\(source.rawValue)-bottom-\(mode)"
                    GridProbes.shared.write(to:path+"-layout.json",window:control.contentView?.bounds.size ?? .zero)
                    try Verification.capture(control,to:path+".png")
                }
                if source == .gradient {
                    let panel = NSColorPanel.shared
                    panel.mode = .RGB; panel.showsAlpha = false
                    panel.color = NSColor(SceneColorBridge.native(model.scene.tint(.gradientStart)))
                    panel.makeKeyAndOrderFront(nil)
                    try await Task.sleep(for:.milliseconds(300))
                    try Verification.capture(panel,to:"\(directory)/source-color-panel-\(mode).png")
                    panel.close()
                }
                if mode == "dark" {
                    model.output.show()
                    try await Task.sleep(for:.milliseconds(250))
                    if let output = model.output.window { try Verification.capture(output,to:"\(directory)/source-output-\(source.rawValue).png") }
                    model.output.window?.performClose(nil)
                }
            }
        }
        model.replaceProject(.init())
    }
}
