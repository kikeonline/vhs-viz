import AppKit
import SwiftUI
import VHSSignal
import VHSCore

/// Uses the same capture switch as prior phases: layout evidence never masquerades as visual review.
enum SignalSnapshots {
    static let appearances: [(String, NSAppearance.Name)] = [
        ("light", .aqua), ("dark", .darkAqua),
        ("light-high-contrast", .accessibilityHighContrastAqua),
        ("dark-high-contrast", .accessibilityHighContrastDarkAqua)
    ]
    static func run(_ model: AppModel, control: NSWindow, directory: String) async throws {
        model.output.window?.close()
        for (mode, appearance) in appearances {
            NSApp.appearance = NSAppearance(named: appearance)
            model.replaceProject(.init(name: String(repeating: "Long project name ", count: 6), scene: .init(source: .shape)))
            for index in 0..<EffectRegistry.maximumEffects { model.addEffect(EffectKind.allCases[index % EffectKind.allCases.count]) }
            if let effect = model.scene.effects.last { model.send(.bypassEffect(effect.id, true)) }
            for (name, size) in [("default", NSSize(width: Layout.defaultWidth, height: Layout.defaultHeight)),
                                 ("minimum", NSSize(width: Layout.minWidth, height: Layout.minHeight)),
                                 ("wide", NSSize(width: 1440, height: 900))] {
                control.setContentSize(size); control.makeKeyAndOrderFront(nil); control.makeFirstResponder(nil)
                try await Task.sleep(for: .milliseconds(200))
                let path = "\(directory)/signal-16-effects-\(name)-\(mode)"
                GridProbes.shared.write(to: path+"-layout.json", window: size)
                try Verification.capture(control, to: path+".png")
            }
        }
        model.replaceProject(.init())
        let gallery = NSWindow(contentRect: .init(x: 0, y: 0, width: Layout.defaultWidth, height: Layout.defaultHeight), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        gallery.isReleasedWhenClosed = false; gallery.title = "Signal component gallery"
        defer { gallery.contentView = nil; gallery.close(); NSApp.appearance = nil }
        control.orderOut(nil)
        for (mode, appearance) in appearances {
            NSApp.appearance = NSAppearance(named: appearance)
            for state in KitState.allCases {
                gallery.contentView = NSHostingView(rootView: KitGallery(states: [state]))
                gallery.makeKeyAndOrderFront(nil); gallery.makeFirstResponder(nil)
                try await Task.sleep(for: .milliseconds(100))
                let path = "\(directory)/signal-gallery-\(state.rawValue)-\(mode)"
                GridProbes.shared.write(to: path+"-layout.json", window: gallery.contentLayoutRect.size)
                try Verification.capture(gallery, to: path+".png")
            }
        }
        control.makeKeyAndOrderFront(nil)
    }
}
