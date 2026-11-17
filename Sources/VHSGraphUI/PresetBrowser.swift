import SwiftUI
import AppKit
import Observation
import UniformTypeIdentifiers
import VHSCore
import VHSSignal

extension UTType {
    public static let vhsPreset = UTType(filenameExtension:"vhspreset",conformingTo:.json)
        ?? UTType(exportedAs:"com.kike.vhs.preset",conformingTo:.json)
}
public enum PresetScope: String, CaseIterable { case factory = "Factory", user = "User" }

@MainActor @Observable public final class PresetBrowserState {
    public var isPresented = false
    public var scope = PresetScope.factory
    public var search = ""
    public var selected: String?
    public var name = "Untitled Preset"
    public private(set) var users: [String] = []
    public private(set) var isBusy = false
    public var message: String?
    @ObservationIgnored public let library: PresetLibrary
    public init(library: PresetLibrary = .init()) { self.library = library }
    public var names: [String] {
        (scope == .factory ? FactoryPresets.all.map(\.name) : users)
            .filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }
    }
    public func refresh() async throws {
        users = try await library.list()
        if let selected, !names.contains(selected) { self.selected = nil }
    }
    public func document() async throws -> PresetDocument {
        guard let selected else { throw PresetError.corrupt }
        if scope == .factory {
            guard let preset = FactoryPresets.all.first(where: { $0.name == selected }) else { throw PresetError.corrupt }
            return preset
        }
        return try await library.read(selected)
    }
    public func perform(_ operation: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true; message = nil
        defer { isBusy = false }
        do { try await operation(); try await refresh() }
        catch ProjectError.destinationExists { message = "A user preset with that name already exists. Choose a different name." }
        catch ProjectError.corrupt { message = "This file is not a valid VHS preset." }
        catch ProjectError.tooLarge { message = "This preset exceeds the supported size. The current scene and library are preserved." }
        catch { message = error.localizedDescription }
    }
}

/// Selection and search are inert. Explicit Load is the only scene-changing action.
public struct PresetBrowser: View {
    @Bindable var state: PresetBrowserState
    let scene: SceneSnapshot
    let load: (PresetDocument) async throws -> Void
    public init(state: PresetBrowserState, scene: SceneSnapshot,
                load: @escaping (PresetDocument) async throws -> Void) {
        self.state = state; self.scene = scene; self.load = load
    }
    public var body: some View {
        VStack(alignment:.leading,spacing:Space.md) {
            HStack {
                Text("Presets").font(KitType.title)
                Spacer()
                Button("Done") { state.isPresented = false }.keyboardShortcut(.cancelAction)
            }.gridProbe("preset-header",area:"preset-browser")
            Picker("Library",selection:$state.scope) {
                ForEach(PresetScope.allCases,id:\.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).gridProbe("preset-scope",area:"preset-browser")
            TextField("Search presets",text:$state.search)
                .accessibilityLabel("Search presets").gridProbe("preset-search",area:"preset-browser")
            List(selection:$state.selected) {
                ForEach(state.names,id:\.self) { name in
                    Label(name,systemImage:state.scope == .factory ? "sparkles" : "doc")
                        .font(KitType.body).padding(.vertical,Space.xs).tag(name)
                }
            }
            .gridProbe("preset-list",area:"preset-browser")
            .overlay {
                if state.names.isEmpty { Text("No presets found").font(KitType.body).foregroundStyle(Ink.secondary) }
            }
            .onChange(of:state.scope) { state.selected = nil }
            .onChange(of:state.search) {
                if let selected = state.selected, !state.names.contains(selected) { state.selected = nil }
            }
            HStack(spacing:Space.sm) {
                Button("Load") { run {
                    let preset = try await state.document()
                    if await confirm("Load “\(preset.name)”?",detail:"This replaces the current scene. Use Undo to restore your edits.",action:"Load") {
                        try await load(preset); state.message = "Loaded “\(preset.name)”."
                    }
                }}.disabled(state.selected == nil)
                Button("Duplicate") { run {
                    let preset = try await state.document()
                    let name = try ProjectDocument.validatedName(state.name)
                    try await state.library.save(preset.named(name))
                    state.scope = .user; state.selected = name
                }}.disabled(state.selected == nil).help("Copy the selected preset using the Name field below")
                Button("Rename") { run {
                    guard state.scope == .user, let selected = state.selected else { throw PresetError.readOnly }
                    let name = try ProjectDocument.validatedName(state.name)
                    try await state.library.rename(selected,to:name); state.selected = name
                }}.disabled(state.scope != .user || state.selected == nil)
                Button("Delete",role:.destructive) { run {
                    guard state.scope == .user, let selected = state.selected else { throw PresetError.readOnly }
                    if await confirm("Delete “\(selected)”?",detail:"Saved projects and songs keep their embedded scenes.",action:"Delete") {
                        try await state.library.delete(selected); state.selected = nil
                    }
                }}.disabled(state.scope != .user || state.selected == nil)
            }.gridProbe("preset-actions",area:"preset-browser")
            Divider().frame(height:Space.xs)
            LabeledContent("Name") {
                TextField("Preset name",text:$state.name)
                    .accessibilityLabel("Preset name for save, duplicate or rename")
            }.font(KitType.body).gridProbe("preset-name",area:"preset-browser")
            HStack(spacing:Space.sm) {
                Button("Save Current Scene") { run {
                    let name = try ProjectDocument.validatedName(state.name)
                    let preset = PresetDocument(name:name,scene:scene)
                    do { try await state.library.save(preset) }
                    catch ProjectError.destinationExists {
                        guard await confirm("Replace “\(name)”?",detail:"The existing user preset will be replaced.",action:"Replace") else { return }
                        try await state.library.save(preset,overwrite:true)
                    }
                    state.scope = .user; state.selected = name
                }}
                Spacer()
                Button("Import…") { run {
                    let panel = NSOpenPanel(); panel.title = "Import Preset"
                    panel.allowedContentTypes = [.vhsPreset,.json]; panel.allowsMultipleSelection = false
                    guard await runPanel(panel) == .OK, let url = panel.url else { return }
                    let preset = try await state.library.readFile(url)
                    do { try await state.library.save(preset) }
                    catch ProjectError.destinationExists {
                        guard await confirm("Replace “\(preset.name)”?",detail:"A user preset with this name exists. Cancel to keep it.",action:"Replace") else { return }
                        try await state.library.save(preset,overwrite:true)
                    }
                    state.scope = .user; state.selected = preset.name
                }}
                Button("Export…") { run {
                    let preset = try await state.document()
                    let panel = NSSavePanel(); panel.title = "Export Preset"
                    panel.allowedContentTypes = [.vhsPreset]; panel.nameFieldStringValue = preset.name + ".vhspreset"
                    guard await runPanel(panel) == .OK, let url = panel.url else { return }
                    // NSSavePanel owns the explicit replacement confirmation.
                    try await state.library.export(preset,to:url,overwrite:true)
                }}.disabled(state.selected == nil)
            }.gridProbe("preset-io",area:"preset-browser")
            if state.isBusy { ProgressView("Preparing preset…").controlSize(.small) }
            if let message = state.message { Text(message).font(KitType.meta).foregroundStyle(Ink.secondary).fixedSize(horizontal:false,vertical:true).accessibilityLabel(message) }
        }
        .padding(Space.margin).gridArea("preset-browser")
        .frame(width:Layout.presetWidth,height:Layout.presetHeight)
        .signalTheme()
        .disabled(state.isBusy)
        .task { await state.perform {} }
    }
    private func run(_ action: @escaping () async throws -> Void) { Task { await state.perform(action) } }
    private func runPanel(_ panel: NSSavePanel) async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            if let window = NSApp.keyWindow { panel.beginSheetModal(for:window) { continuation.resume(returning:$0) } }
            else { panel.begin { continuation.resume(returning:$0) } }
        }
    }
    private func confirm(_ title: String, detail: String, action: String) async -> Bool {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = detail
        alert.addButton(withTitle:action); alert.addButton(withTitle:"Cancel").keyEquivalent = "\u{1b}"
        if let window = NSApp.keyWindow {
            return await withCheckedContinuation { continuation in
                alert.beginSheetModal(for:window) { continuation.resume(returning:$0 == .alertFirstButtonReturn) }
            }
        }
        return alert.runModal() == .alertFirstButtonReturn
    }
}
