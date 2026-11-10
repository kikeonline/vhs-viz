import AppKit
import VHSCore

enum EffectSnapshots {
    static func run(_ model: AppModel, control: NSWindow, directory: String) async throws {
        model.output.window?.performClose(nil)
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            for kind in EffectKind.allCases {
                model.replaceProject(.init(scene: .init(source: .shape)))
                model.addEffect(kind)
                for (suffix,size) in [("",NSSize(width:Layout.defaultWidth,height:Layout.defaultHeight)),
                                      ("-minimum",NSSize(width:Layout.minWidth,height:Layout.minHeight))] {
                    control.setContentSize(size)
                    NSApp.activate(); control.makeKeyAndOrderFront(nil); control.makeFirstResponder(nil)
                    try await Task.sleep(for: .milliseconds(300))
                    let path = "\(directory)/effect-\(kind.rawValue)\(suffix)-\(mode)"
                    GridProbes.shared.write(to:path+"-layout.json",window:size)
                    try Verification.capture(control,to:path+".png")
                }
            }
            model.replaceProject(.init(scene: .init(source: .gradient)))
            for kind in [.blur, .threshold, .colorize, .blur] as [EffectKind] { model.addEffect(kind) }
            model.send(.bypassEffect(model.scene.effects[0].id,true))
            control.setContentSize(.init(width:Layout.defaultWidth,height:Layout.defaultHeight))
            NSApp.activate(); control.makeKeyAndOrderFront(nil); control.makeFirstResponder(nil)
            try await Task.sleep(for: .milliseconds(300))
            let path = "\(directory)/effects-chain-\(mode)"
            GridProbes.shared.write(to:path+"-layout.json",window:control.contentView?.bounds.size ?? .zero)
            try Verification.capture(control,to:path+".png")
            if mode == "dark" {
                model.output.show()
                try await Task.sleep(for: .milliseconds(300))
                try Verification.capture(model.output.window!,to:"\(directory)/effects-output.png")
                model.output.window?.performClose(nil)
            }
        }
        model.replaceProject(.init())
    }
}
