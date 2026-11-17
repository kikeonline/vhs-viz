import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VHSCore
import VHSSignal
import VHSGraphUI

struct HostControls: View {
    let runtime: PluginRuntime
    @State private var exposing: GraphParameterTarget?
    @State private var exposedSlot: Int?
    private var graph: ShaderGraph { runtime.session.history.scene.graph }
    private var targets: [GraphParameterTarget] {
        graph.nodes.flatMap { node in node.kind.parameters.compactMap { parameter in
            let target = GraphParameterTarget(node:node.id,key:parameter.id)
            return target.definition(in:graph) != nil && graph.input(node.id,parameter.id) == nil ? target : nil
        }}
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment:.leading,spacing:Space.lg) {
                Text("Host Controls").font(KitType.title)
                Picker("Clock",selection:Binding(get:{runtime.session.history.scene.sync},set:{runtime.sendGraph(.setSync($0))})) {
                    Text("Free Run · seconds").tag(SceneSync.freeRun)
                    Text("Follow DAW · beats").tag(SceneSync.followDAW)
                }
                Text(runtime.clockStatus).font(KitType.meta).foregroundStyle(Ink.secondary)
                Text("Follow DAW uses one quarter note per animation second. Frequency values then mean cycles per beat. Missing timing holds the last beat.")
                    .font(KitType.meta).foregroundStyle(Ink.secondary).fixedSize(horizontal:false,vertical:true)
                Text(!runtime.hostInputAvailable ? "Host audio unavailable" : (runtime.audioSignals.ready ? "Host audio analysis ready" : "Waiting for host audio window"))
                    .font(KitType.body)
                if runtime.hostInputAvailable && runtime.audioSignals.ready {
                    Text("RMS \(runtime.audioSignals.rms,format:.number.precision(.fractionLength(3))) · Peak \(runtime.audioSignals.peak,format:.number.precision(.fractionLength(3)))")
                        .font(KitType.value)
                }
                Picker("Expose parameter",selection:$exposing) {
                    Text("Choose a parameter").tag(nil as GraphParameterTarget?)
                    ForEach(targets,id:\.self) { Text(label($0)).tag($0 as GraphParameterTarget?) }
                }
                Button("Expose to Host") { if let exposing { exposedSlot = runtime.expose(exposing) } }.disabled(exposing == nil)
                    .help("Assign the lowest never-used slot; existing targets keep their slot")
                if let exposedSlot { Text("Exposed as Visual \(exposedSlot+1)").font(KitType.meta).foregroundStyle(Ink.secondary) }
                if let error = runtime.error { Text(error).font(KitType.meta).foregroundStyle(Ink.error).fixedSize(horizontal:false,vertical:true) }
                ForEach(0..<HostAutomationBinding.capacity,id:\.self) { slot in
                    VStack(alignment:.leading,spacing:Space.sm) {
                        let binding = runtime.bindings.first { $0.slot == slot }
                        Picker("Visual \(slot+1)",selection:Binding(get:{binding?.enabled == true ? binding?.target : nil},set:{runtime.bind(slot:slot,to:$0)})) {
                            Text("Unassigned").tag(nil as GraphParameterTarget?)
                            ForEach(targets,id:\.self) { target in
                                Text(label(target)).tag(target as GraphParameterTarget?)
                                    .disabled(runtime.bindings.contains { $0.slot != slot && $0.target == target })
                            }
                            if let binding, binding.enabled, !targets.contains(binding.target) {
                                Text("Unavailable · \(binding.target.key)").tag(binding.target as GraphParameterTarget?)
                            }
                        }
                        if let binding, !binding.enabled {
                            Text("Reserved lane · rebind explicitly to reuse").font(KitType.meta).foregroundStyle(Ink.secondary)
                        }
                        if let binding, binding.enabled {
                            if binding.range(in:graph) == nil {
                                Label(binding.target.unavailableMessage,systemImage:KitIcon.warning.rawValue)
                                    .font(KitType.meta).foregroundStyle(Ink.secondary).fixedSize(horizontal:false,vertical:true)
                            } else {
                                NumericParameter("Visual \(slot+1) host value",value:runtime.hostValues[slot] ?? 0,
                                    range:0...1,defaultValue:binding.normalized(in:graph) ?? 0,
                                    change:{runtime.edit(binding.parameterID,$0,1)},
                                    exactChange:{ value in
                                        runtime.edit(binding.parameterID,value,0); runtime.edit(binding.parameterID,value,1); runtime.edit(binding.parameterID,value,2)
                                    },beginEdit:{runtime.edit(binding.parameterID,runtime.hostValues[slot] ?? 0,0)},
                                    endEdit:{runtime.edit(binding.parameterID,runtime.hostValues[slot] ?? 0,2)})
                            }
                        }
                    }
                    Divider()
                }
            }.padding(Space.margin)
        }.frame(width:Layout.mappingWidth,height:Layout.mappingHeight).signalTheme()
    }
    private func label(_ target: GraphParameterTarget) -> String {
        "\(graph.node(target.node)?.kind.title ?? "Missing") · \(target.definition(in:graph)?.title ?? target.key) · \(target.node.uuidString.prefix(4))"
    }
}

extension PluginRuntime {
    private func panel(_ panel: NSSavePanel) async -> URL? {
        let response: NSApplication.ModalResponse = await withCheckedContinuation { continuation in
            if let window = NSApp.keyWindow { panel.beginSheetModal(for:window) { continuation.resume(returning:$0) } }
            else { panel.begin { continuation.resume(returning:$0) } }
        }
        return response == .OK ? panel.url : nil
    }
    func importProject() async {
        guard !filesBusy else { return }
        filesBusy = true; defer { filesBusy = false }
        let chooser = NSOpenPanel(); chooser.title = "Import Project into VHS"
        chooser.allowedContentTypes = [UTType(filenameExtension:"vhsproject",conformingTo:.json) ?? .json]
        chooser.allowsMultipleSelection = false
        guard let url = await panel(chooser) else { return }
        do { try await importProject(from:url) } catch { self.error = error.localizedDescription }
    }
    func importProject(from url: URL) async throws {
        let original = session.document
        let project = try await ProjectIO().read(from:url)
        _ = try await render.preparePreset(.init(name:project.name,scene:project.scene))
        guard session.document == original else { throw PresetError.changed }
        let replacement = ProjectDocument(id:session.id,name:session.name,scene:project.scene,graphLayout:project.graphLayout)
        _ = try HostDocumentCodec.encode(.init(project:replacement,bindings:bindings))
        session.send(.replaceScene(project.scene)); session.setGraphLayout(project.graphLayout)
        mappingEditor.cancel(); graphEditor.selection = nil; showsGraph = true
        syncImportedBase(); publishImportedProject()
    }
    func exportProject() async {
        guard !filesBusy else { return }
        filesBusy = true; defer { filesBusy = false }
        let chooser = NSSavePanel(); chooser.title = "Export VHS Project"
        chooser.allowedContentTypes = [UTType(filenameExtension:"vhsproject",conformingTo:.json) ?? .json]
        chooser.nameFieldStringValue = session.name + ".vhsproject"
        guard let url = await panel(chooser) else { return }
        do { try await exportProject(to:url) } catch { self.error = error.localizedDescription }
    }
    func exportProject(to url: URL) async throws {
        let project = ProjectDocument(name:session.name,scene:hostBaseScene,graphLayout:session.graphLayout)
        try await ProjectIO().write(project,to:url)
    }
}
