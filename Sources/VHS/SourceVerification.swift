import AppKit
import MetalKit
import SwiftUI
import VHSCore

enum SourceVerification {
    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw ProjectVerification.Failure(message: message) }
        Verification.log("PASS \(message)")
    }
    private static func coordinator(_ view: NSView) -> MetalSurface.Coordinator? {
        if let view = view as? MTKView { return view.delegate as? MetalSurface.Coordinator }
        return view.subviews.lazy.compactMap { coordinator($0) }.first
    }
    static func run(_ model: AppModel) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VHS-source-selftest-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        guard let halfGray = SceneColorBridge.scene(Color(.sRGB,red:0.5,green:0.5,blue:0.5)) else {
            throw ProjectVerification.Failure(message:"Native color conversion unavailable")
        }
        try check(abs(halfGray.red-0.21404114) < 0.00001, "Native sRGB color picker converts to linear RGB")
        let roundTrip = SceneColorBridge.scene(SceneColorBridge.native(.initial))
        try check(roundTrip.map { abs($0.red-0.24) < 0.00001 && abs($0.green-0.08) < 0.00001 && abs($0.blue-0.62) < 0.00001 } == true,
                  "Linear scene color survives native color picker round trip")
        model.output.show()
        for source in SourceKind.allCases {
            model.send(.selectSource(source))
            let before = model.scene
            for parameter in source.definition.parameters {
                switch parameter.kind {
                case let .number(range):
                    model.beginEdit()
                    model.send(.setValue(parameter.id,.number(range.lowerBound)))
                    model.send(.setValue(parameter.id,.number(range.upperBound)))
                    model.endEdit()
                case .integer: model.send(.setValue(parameter.id,.number(42)))
                case let .choice(options): model.send(.setValue(parameter.id,.choice(options.last!.id)))
                case .color: model.send(.setValue(parameter.id,.color(.init(red:0.6,green:0.2,blue:0.8))))
                case .toggle: model.send(.setValue(parameter.id,.toggle(!model.scene.enabled(parameter.id))))
                }
                let edited = model.scene
                model.undo(); model.redo()
                try check(model.scene == edited, "\(source.definition.title) \(parameter.title) undo/redo")
            }
            let saved = model.scene
            try check(saved != before && model.isDirty, "\(source.definition.title) typed edits mark project dirty")
            let url = directory.appendingPathComponent(source.rawValue).appendingPathExtension("vhsproject")
            try check(await model.files.saveProject(to:url), "\(source.definition.title) saves")
            model.replaceProject(.init())
            await model.files.openProject(url)
            try check(model.scene == saved && !model.isDirty && !model.history.canUndo,
                      "\(source.definition.title) Open restores source, all values and seed with fresh history")
            try await Task.sleep(for:.milliseconds(250))
            guard let control = NSApp.windows.first(where: { $0.identifier?.rawValue == "vhs-control" }),
                  let preview = control.contentView.flatMap({ coordinator($0) }),
                  let output = model.output.window?.contentView.flatMap({ coordinator($0) }) else {
                throw ProjectVerification.Failure(message:"Live source surfaces missing")
            }
            try check(preview.lastScene == saved && output.lastScene == saved,
                      "\(source.definition.title) preview/output draw the same restored snapshot")
            let count = preview.drawableFrameCount
            try await Task.sleep(for:.milliseconds(100))
            try check(preview.drawableFrameCount > count && model.errorMessage == nil && !model.isDirty && model.history.past.isEmpty, "\(source.definition.title) stays live without dirty or undo entries")
        }
        model.output.window?.performClose(nil)
        model.replaceProject(.init())
        Verification.log("PASS all procedural sources self-test")
    }
}
