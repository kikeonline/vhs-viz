import AppKit
import MetalKit
import VHSCore

enum EffectVerification {
    private static func check(_ value: Bool, _ message: String) throws {
        guard value else { throw ProjectVerification.Failure(message: message) }
        Verification.log("PASS \(message)")
    }
    private static func coordinator(_ view: NSView) -> MetalSurface.Coordinator? {
        if let metal = view as? MTKView { return metal.delegate as? MetalSurface.Coordinator }
        return view.subviews.lazy.compactMap { coordinator($0) }.first
    }
    static func run(_ model: AppModel) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VHS-effects-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        model.replaceProject(.init(scene: .init(source: .gradient)))
        model.output.show()
        for kind in EffectKind.allCases {
            model.addEffect(kind)
            guard let effect = model.selectedEffect else { throw ProjectVerification.Failure(message: "Added effect is not selected") }
            let before = model.scene
            for parameter in kind.definition.parameters {
                model.beginEdit()
                switch parameter.kind {
                case let .number(range):
                    model.send(.setEffectValue(effect.id, parameter.id, .number(range.lowerBound)))
                    model.send(.setEffectValue(effect.id, parameter.id, .number(range.upperBound)))
                case .color: model.send(.setEffectValue(effect.id, parameter.id, .color(.init(red:0.9,green:0.3,blue:0.2))))
                default: break
                }
                model.endEdit()
                let edited = model.scene
                model.undo(); model.redo()
                try check(model.scene == edited, "\(kind.definition.title) \(parameter.title) grouped undo/redo")
            }
            try check(model.scene != before, "\(kind.definition.title) edits update scene")
            model.send(.bypassEffect(effect.id, true)); model.undo()
            try check(model.selectedEffect?.bypassed == false, "\(kind.definition.title) bypass undo preserves selection")
        }
        model.addEffect(.blur)
        let repeated = model.selectedEffectID!
        try check(model.scene.effects.filter { $0.kind == .blur }.count == 2, "Repeated effects have independent identities")
        model.moveEffect(repeated, by: -1)
        try check(model.scene.effects[model.scene.effects.count-2].id == repeated, "Move Up preserves effect selection and identity")
        model.moveEffect(repeated, by: 1)
        let complete = model.scene
        model.removeEffect(repeated)
        try check(model.selectedEffectID == nil, "Removing selected effect returns to source inspector")
        model.undo()
        try check(model.scene == complete, "Undo restores removed effect and original identity")
        model.selectEffect(complete.effects[0].id)
        let count = model.history.past.count
        model.selectEffect(nil)
        try check(model.history.past.count == count, "Inspector selection stays outside scene history")
        let url = directory.appendingPathComponent("Effects.vhsproject")
        try check(await model.files.saveProject(to: url), "Effect chain saves")
        model.replaceProject(.init())
        await model.files.openProject(url)
        try check(model.scene == complete && !model.isDirty, "Open restores ordered effects, settings, bypass and UUIDs")
        let bad = directory.appendingPathComponent("Broken.vhsproject")
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String:Any]
        var scene = json["scene"] as! [String:Any]; var effects = scene["effects"] as! [[String:Any]]
        effects[0]["kind"] = "unknown"; scene["effects"] = effects; json["scene"] = scene
        try JSONSerialization.data(withJSONObject: json).write(to: bad)
        let dialogs = EffectErrorDialogs(); let originalDialogs = model.files.dialogs
        model.files.dialogs = dialogs
        await model.files.openProject(bad)
        model.files.dialogs = originalDialogs
        try check(dialogs.errors == 1 && model.scene == complete, "Malformed effect file preserves current scene")
        guard let control = NSApp.windows.first(where: { $0.identifier?.rawValue == "vhs-control" }),
              let preview = control.contentView.flatMap({ coordinator($0) }),
              let output = model.output.window?.contentView.flatMap({ coordinator($0) }) else {
            throw ProjectVerification.Failure(message: "Effect live surfaces missing")
        }
        for index in 0..<12 {
            model.output.window?.setContentSize(.init(width: index%2 == 0 ? 640 : 800, height: index%2 == 0 ? 360 : 480))
            let first = model.scene.effects[0]
            model.send(.bypassEffect(first.id, index%2 == 0))
            try await Task.sleep(for: .milliseconds(80))
            try check(model.renderer!.resourceMetrics.textures <= 6, "Resize/chain edit \(index+1) retains at most six intermediate textures")
        }
        try await Task.sleep(for: .milliseconds(200))
        try check(preview.lastScene == model.scene && output.lastScene == model.scene && model.errorMessage == nil,
                  "Effect preview/output share the same live snapshot after resize and chain edits")
        model.output.window?.performClose(nil)
        model.replaceProject(.init())
        Verification.log("PASS ordered effects self-test")
    }
}
private final class EffectErrorDialogs: ProjectDialogs {
    var errors = 0
    func chooseOpenURL() async -> URL? { nil }
    func chooseSaveURL(name: String, currentURL: URL?) async -> URL? { nil }
    func confirmUnsaved(name: String) async -> UnsavedChoice { .cancel }
    func showError(title: String, message: String) async { errors += 1 }
}
